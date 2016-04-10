//
//  CNTestView.h
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/9/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CNSplitView;
@import Cocoa;

@interface CNTestView : NSObject

- (CNSplitViewToolbar*)getCNToolBar;
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;

@end
