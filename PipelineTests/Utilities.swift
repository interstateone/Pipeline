//
//  Utilities.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-23.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation

let background = { then in
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), then)
}

let onMainAfter: (Double, () -> ()) -> () = { seconds, then in
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), then)
}
