//
//  TimeInterval+Extensions.swift
//
//
//  Created by Charles Wright on 4/5/24.
//

import Foundation

extension TimeInterval {
    public static func minutes(_ m: Double) -> TimeInterval {
        60.0 * m
    }
    public static func minutes(_ m: Int) -> TimeInterval {
        60.0 * Double(m)
    }
    
    public static func hours(_ h: Double) -> TimeInterval {
        3600.0 * h
    }
    public static func hours(_ h: Int) -> TimeInterval {
        3600.0 * Double(h)
    }
    
    public static func days(_ d: Double) -> TimeInterval {
        86400.0 * d
    }
    public static func days(_ d: Int) -> TimeInterval {
        86400.0 * Double(d)
    }
}
