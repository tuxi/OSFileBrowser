//
//  MonitorFileChangeHelper.h
//  FileBrowser
//
//  Created by Ossey on 2017/7/19.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MonitorFileChangeHelper : NSObject

- (void)watcherForPath:(NSString *)path block:(void (^)(NSInteger type))block;

@end
