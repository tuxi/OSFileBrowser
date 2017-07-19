//
//  FileTableViewCell.m
//  FileBrowser
//
//  Created by Ossey on 2017/7/1.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FileTableViewCell.h"
#import "NSString+FileExtend.h"

@interface FileTableViewCell ()

@end

@implementation FileTableViewCell

- (void)setPath:(NSString *)path {
    _path = path;
    
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    self.textLabel.text = [path lastPathComponent];
    
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@", [NSString transformedFileSizeValue:@([path fileSize])]];
    if (isDirectory) {
        self.imageView.image = [UIImage imageNamed:@"Folder"];
    } else if ([path.pathExtension.lowercaseString isEqualToString:@"png"]
               || [path.pathExtension.lowercaseString isEqualToString:@"jpg"]) {
        self.imageView.image = [UIImage imageNamed:@"Picture"];
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


