//
//  FileAttributeItem.m
//  FileBrowser
//
//  Created by Ossey on 2017/7/20.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FileAttributeItem.h"

@implementation FileAttributeItem

- (void)getProgress {
    if (self.progress) {
        self.progress = nil;
    }
    NSProgress *progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress]
                                                     userInfo:nil];
    progress.kind = NSProgressKindFile;
    [progress setUserInfoObject:NSProgressFileOperationKindKey
                         forKey:NSProgressFileOperationKindDownloading];
    [progress setUserInfoObject:self.fullPath forKey:@"fullPath"];
    progress.cancellable = NO;
    progress.pausable = NO;
    progress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    progress.completedUnitCount = 0;
    self.progress = progress;
}

- (void)setTotalFileSize:(int64_t)totalFileSize {
    _totalFileSize = totalFileSize;
    if (self.progress && totalFileSize > 0) {
        self.progress.totalUnitCount = totalFileSize;
    }
}

- (void)setReceivedFileSize:(int64_t)receivedFileSize {
    _receivedFileSize = receivedFileSize;
    if (receivedFileSize > 0) {
        if (self.progress && self.totalFileSize > 0) {
            self.progress.completedUnitCount = receivedFileSize;
        }
    }

}

@end
