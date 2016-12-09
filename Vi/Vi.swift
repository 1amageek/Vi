//
//  Vi.swift
//  Vi
//
//  Created by 1amageek on 2016/12/09.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import AVFoundation
import CoreMedia
import UIKit

protocol ViControl {
    
    var status: AVPlayerStatus { get }
    func play()
    func pause()
    func stop()
}

public class Vi: UIView {
    
    private struct ObserverContexts {
        static var playerStatus = 0
        
        static var playerStatusKey = "status"
        
        static var currentItem = 0
        
        static var currentItemKey = "currentItem"
        
        static var currentItemStatus = 0
        
        static var currentItemStatusKey = "currentItem.status"
        
        static var urlAssetDurationKey = "duration"
        
        static var urlAssetPlayableKey = "playable"
        
        static var urlAssetHasProtectedContentKey = "hasProtectedContent"
    }
    
    /// Player
    let player = AVQueuePlayer()
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
    override public class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var currentTime: Double {
        get { return CMTimeGetSeconds(self.player.currentTime()) }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            self.player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var duration: Double {
        guard let currentItem = player.currentItem else { return 0.0 }
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    var rate: Float {
        get { return player.rate }
        set { player.rate = newValue }
    }
    
    var asset: AVURLAsset? {
        didSet {
            self.removeTimeObserverToken()
            guard let newAsset = asset else { return }
            self.asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
    private var playerItem: AVPlayerItem? = nil {
        didSet {
            self.player.replaceCurrentItem(with: self.playerItem)
        }
    }
    
    private var isObserving = false
    
    func asynchronouslyLoadURLAsset(_ newAsset: AVURLAsset) {

        let assetKeysRequiredToPlay: [String] = [ObserverContexts.urlAssetDurationKey,
                                                 ObserverContexts.urlAssetPlayableKey,
                                                 ObserverContexts.urlAssetHasProtectedContentKey]
        
        newAsset.loadValuesAsynchronously(forKeys: assetKeysRequiredToPlay) {
            /*
             The asset invokes its completion handler on an arbitrary queue.
             To avoid multiple threads using our internal state at the same time
             we'll elect to use the main thread at all times, let's dispatch
             our handler to the main queue.
             */
            DispatchQueue.main.async {
                /*
                 `self.asset` has already changed! No point continuing because
                 another `newAsset` will come along in a moment.
                 */
                guard newAsset == self.asset else { return }
                
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in assetKeysRequiredToPlay {
                    var error: NSError?
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let message = String.localizedStringWithFormat("Can't use this AVAsset because %@ failed to load.", key)
                        self.handleErrorWithMessage(message, error: error)
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    self.handleErrorWithMessage(message)
                    return
                }
                
                /*
                 We can play this asset. Create a new `AVPlayerItem` and make
                 it our player's current item.
                 */
                self.playerItem = AVPlayerItem(asset: newAsset)
                
                
                let interval: CMTime = CMTimeMake(1, 1)
                self.timeObserverToken = self.player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
                    let timeElapsed = Float(CMTimeGetSeconds(time))
                    
                }
                
            }
        }
    }
    
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
//        NSLog("Error occured with message: \(message), error: \(error).")
//        
//        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
//        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")
//        
//        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: UIAlertControllerStyle.alert)
//        
//        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")
//        
//        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
//        
//        alert.addAction(alertAction)
//        
//        present(alert, animated: true, completion: nil)
    }
    
    /*
     A formatter for individual date components used to provide an appropriate
     value for the `startTimeLabel` and `durationLabel`.
     */
    let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
    
    /*
     A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
     method.
     */
    private var timeObserverToken: Any?
    
    // MARK: Convenience
    
    private func startObserving() {
        if self.isObserving { return }
        self.player.addObserver(self, forKeyPath: ObserverContexts.playerStatusKey, options: .new, context: &ObserverContexts.playerStatus)
        self.player.addObserver(self, forKeyPath: ObserverContexts.currentItemKey, options: .old, context: &ObserverContexts.currentItem)
        self.player.addObserver(self, forKeyPath: ObserverContexts.currentItemStatusKey, options: .new, context: &ObserverContexts.currentItemStatus)
        self.isObserving = true
    }
    
    private func stopObserving() {
        if !self.isObserving { return }
        self.player.removeObserver(self, forKeyPath: ObserverContexts.playerStatusKey, context: &ObserverContexts.playerStatus)
        self.player.removeObserver(self, forKeyPath: ObserverContexts.currentItemKey, context: &ObserverContexts.currentItem)
        self.player.removeObserver(self, forKeyPath: ObserverContexts.currentItemStatusKey, context: &ObserverContexts.currentItemStatus)
        self.isObserving = false
    }
    
    private func removeTimeObserverToken() {
        if let timeObserverToken = self.timeObserverToken {
            self.player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    // MARK: KVO
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &ObserverContexts.playerStatus {
            guard let newPlayerStatus = change?[.newKey] as? AVPlayerStatus else { return }
            if newPlayerStatus == AVPlayerStatus.failed {
                print("End looping since player has failed with error: \(player.error)")
                stop()
            }
        } else if context == &ObserverContexts.currentItem {
            if self.player.items().isEmpty {
                print("Play queue emptied out due to bad player item. End looping")
                stop()
            } else {
                if let itemRemoved = change?[.oldKey] as? AVPlayerItem {
                    itemRemoved.seek(to: kCMTimeZero)
                    stopObserving()
                    player.insert(itemRemoved, after: nil)
                    startObserving()
                }
            }
        } else if context == &ObserverContexts.currentItemStatus {
            guard let newPlayerItemStatus = change?[.newKey] as? AVPlayerItemStatus else { return }
            if newPlayerItemStatus == .failed {
                print("End looping since player item has failed with error: \(self.player.currentItem?.error)")
                stop()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
}

extension Vi: ViControl {
    
    var status: AVPlayerStatus {
        return self.player.status
    }
    
    func play() {
        
    }
    
    func pause() {
        if self.player.rate != 1.0 {
            if currentTime == self.duration {
                self.currentTime = 0.0
            }
            self.player.play()
        } else {
            self.player.pause()
        }
    }
    
    func stop() {
        
    }
}
