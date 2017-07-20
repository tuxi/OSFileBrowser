//
//  NSFileManager+FileOperationExtend.m
//  FileBrowser
//
//  Created by Ossey on 2017/7/20.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "NSFileManager+FileOperationExtend.h"
#import "NSString+FileExtend.h"
#import <objc/runtime.h>

@interface NSFileManager ()

@property (nonatomic, strong) dispatch_queue_t writeQueue;
@property (nonatomic, strong) dispatch_queue_t readQueue;
@property (nonatomic, strong) NSOperationQueue *fileQueue;

@end

@implementation NSFileManager (FileOperationExtend)

- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath handler:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize, NSError *error))copyHandler {
    __block BOOL res = NO;
    __block NSError *copyError = nil;
    [self.fileQueue addOperationWithBlock:^{
        res = [self copyItemAtPath:srcPath toPath:dstPath error:&copyError];
    }];
    
    [self.fileQueue addOperationWithBlock:^{
        [[self class] readFileSizeForFilePath:dstPath finishedCopyBlock:^(BOOL isFinishedCopy, unsigned long long receivedFileSize) {
            if (copyHandler) {
                copyHandler(isFinishedCopy, receivedFileSize, copyError);
            }
        }];
    }];
    
    return res;
}

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath handler:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize, NSError *error))moveHandler {
    __block BOOL res = NO;
    __block NSError *moveError = nil;
    [self.fileQueue addOperationWithBlock:^{
        res = [self moveItemAtPath:srcPath toPath:dstPath error:&moveError];
    }];
    [self.fileQueue addOperationWithBlock:^{
        [[self class] readFileSizeForFilePath:dstPath finishedCopyBlock:^(BOOL isFinishedCopy, unsigned long long receivedFileSize) {
            if (moveHandler) {
                moveHandler(isFinishedCopy, receivedFileSize, moveError);
            }
        }];
    }];
    return res;
}


+ (void)readFileSizeForFilePath:(NSString *)filePath finishedCopyBlock:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize))isFinishedCopy {
    unsigned long long lastSize = 0;
    NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSInteger fileSize = [[fileAttrs objectForKey:NSFileSize] intValue];
    
    do {
        lastSize = fileSize;
        [NSThread sleepForTimeInterval:0.2];
        if (isFinishedCopy) {
            isFinishedCopy(NO, lastSize);
        }
        NSLog(@"文件正在写入, 已写入大小:%llu", lastSize);
        /*
         fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
         fileSize = [[fileAttrs objectForKey:NSFileSize] intValue];
         */
        fileSize = [filePath fileSize];
        
    } while (lastSize != fileSize);
    
    if (isFinishedCopy) {
        isFinishedCopy(YES, lastSize);
    }
    NSLog(@"文件写入完成, 总大小:%ld", fileSize);
    
}


- (NSOperationQueue *)fileQueue {
    NSOperationQueue *queue = objc_getAssociatedObject(self, _cmd);
    if (!queue) {
        queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 2;
        queue.name = @"com.FileBrowser.FileOperationExtend_queue";
        objc_setAssociatedObject(self, _cmd, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return queue;
}

@end

