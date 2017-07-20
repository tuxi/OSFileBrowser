//
//  FileTableViewCell.m
//  FileBrowser
//
//  Created by Ossey on 2017/7/1.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FileTableViewCell.h"
#import "NSString+FileExtend.h"
#import "FileAttributeItem.h"

@interface FileTableViewCell ()

@end

@implementation FileTableViewCell


- (void)setFileModel:(FileAttributeItem *)fileModel {
    _fileModel = fileModel;
    
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fileModel.fullPath isDirectory:&isDirectory];
    self.textLabel.text = [fileModel.fullPath lastPathComponent];
    //    self.detailTextLabel.text = fileModel.fileSize;
    self.detailTextLabel.text = nil;
    if (isDirectory) {
        self.imageView.image = [UIImage imageNamed:@"Folder"];
        self.detailTextLabel.text = [NSString stringWithFormat:@"%ld个文件", fileModel.subFileCount];
    } else if ([fileModel.fullPath.pathExtension.lowercaseString isEqualToString:@"png"] ||
               [fileModel.fullPath.pathExtension.lowercaseString isEqualToString:@"jpg"]) {
        self.imageView.image = [UIImage imageNamed:@"Picture"];
        //        self.imageView.image = [UIImage imageWithContentsOfFile:path];
    } else {
        self.imageView.image = nil;
    }
    if (fileExists && !isDirectory) {
        self.accessoryType = UITableViewCellAccessoryDetailButton;
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
}


@end


