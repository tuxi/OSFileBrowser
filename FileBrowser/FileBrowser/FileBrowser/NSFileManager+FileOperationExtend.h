//
//  NSFileManager+FileOperationExtend.h
//  FileBrowser
//
//  Created by Ossey on 2017/7/20.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (FileOperationExtend)

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath handler:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize, NSError *error))moveHandler;

- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath handler:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize, NSError *error))copyHandler;

+ (void)readFileSizeForFilePath:(NSString *)filePath finishedCopyBlock:(void (^)(BOOL isFinishedCopy, unsigned long long receivedFileSize))isFinishedCopy;

@end
