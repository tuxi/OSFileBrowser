//
//  FileAttributeItem.h
//  FileBrowser
//
//  Created by Ossey on 2017/7/20.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileAttributeItem : NSObject

@property (nonatomic, copy) NSString *fullPath;
@property (nonatomic, assign) int64_t totalFileSize;
@property (nonatomic, assign) int64_t receivedFileSize;
@property (nonatomic, assign) NSUInteger subFileCount;
@property (nonatomic, strong) NSProgress *progress;

- (void)getProgress;;

@end
