//
//  HapticPattern.swift
//  CoreHapticsApi
//
//  Created by julian on 4/16/21.
//  Copyright © 2021 Facebook. All rights reserved.
//

import Foundation
import CoreHaptics

/**
 Typescript interface
 export default interface HapticPattern {
   hapticEvents: [HapticEvent]
 }
 */
typealias HapticPattern = [String: AnyHashable]

/**
 iOS-only object interface that represents the Typescript interfaces through lazy interpretation of the values directly in JSON.
 */
class HapticPatternObject {
    class Key {
        // HapticPattern
        static let hapticEvents = "hapticEvents"
        static let parameterCurves = "parameterCurves"
        
        // HapticEvent
        static let eventType = "eventType"
        static let parameters = "parameters"
        static let relativeTime = "relativeTime"
        static let duration = "duration"
        
        // HapticEventParameter
        static let parameterID = "parameterID"
        static let value = "value"
        
        // HapticEventEventType, HapticEventParameterID
        static let rawValue = "rawValue"
        
        // Parameter Curves
        static let controlPoints = "controlPoints"
        static let time = "time"
    }
    
    let json: [String: Any]
    init(_ json: HapticPattern) {
        self.json = json
    }
    
    var hapticEvents: [[String: Any]]? {
        return self.json[Key.hapticEvents] as? [[String: Any]]
    }
    
    var parameterCurves: [[String: Any]]? {
        return self.json[Key.parameterCurves] as? [[String: Any]]
    }
    
    func toHapticPattern() -> CHHapticPattern? {
        guard let jsonEvents = hapticEvents else {
            return nil
        }
        
        let events: [CHHapticEvent] = jsonEvents.compactMap { event in
            guard let eventTypeObject = event[Key.eventType] as? [String: Any] else {
                return nil
            }
            
            guard let eventTypeRawValue = eventTypeObject[Key.rawValue] as? String else {
                return nil
            }
            
            let eventType = CHHapticEvent.EventType(rawValue: eventTypeRawValue)
            
            guard let eventParameterObjects = event[Key.parameters] as? [[String: Any]] else {
                return nil
            }
            
            let eventParameters: [CHHapticEventParameter] = eventParameterObjects.compactMap { parameterObject in
                guard let parameterIDObject = parameterObject[Key.parameterID] as? [String: Any] else {
                    return nil
                }
                
                guard let parameterIDRawValue = parameterIDObject[Key.rawValue] as? String else {
                    return nil
                }
                
                let parameterID = CHHapticEvent.ParameterID(rawValue: parameterIDRawValue)
                
                guard let value = parameterObject[Key.value] as? Float else {
                    return nil
                }
                
                let parameter = CHHapticEventParameter(parameterID: parameterID, value: value)
                return parameter
            }
            
            guard let relativeTime = event[Key.relativeTime] as? TimeInterval,
                  let duration = event[Key.duration] as? TimeInterval else {
                return nil
            }
            
            let event = CHHapticEvent(eventType: eventType, parameters: eventParameters, relativeTime: relativeTime, duration: duration)
            return event
        }
        // ✅ NEW: Handle parameter curves
               var curves: [CHHapticParameterCurve] = []

               if let jsonCurves = parameterCurves {
                   for curve in jsonCurves {
                       guard let paramIDObject = curve[Key.parameterID] as? [String: Any],
                             let paramIDRaw = paramIDObject[Key.rawValue] as? String,
                             let relativeTime = curve[Key.relativeTime] as? TimeInterval,
                             let controlPoints = curve[Key.controlPoints] as? [[String: Any]] else {
                           continue
                       }

                       let parameterID = CHHapticDynamicParameter.ID(rawValue: paramIDRaw)

                       let points: [CHHapticParameterCurve.ControlPoint] = controlPoints.compactMap { point in
                           guard let time = (point[Key.time] as? NSNumber)?.doubleValue,
                                 let value = (point[Key.value] as? NSNumber)?.floatValue else {
                               print("⚠️ Skipping controlPoint with invalid types: \(point)")
                               return nil
                           }

                           return CHHapticParameterCurve.ControlPoint(relativeTime: time, value: value)
                       }

                       let curveObject = CHHapticParameterCurve(parameterID: parameterID, controlPoints: points, relativeTime: relativeTime)
                       curves.append(curveObject)
                   }
               }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            return pattern
        } catch let _ {
            return nil
        }
    }
}
