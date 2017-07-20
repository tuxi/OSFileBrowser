//
//  FileTableViewCell.h
//  FileBrowser
//
//  Created by Ossey on 2017/7/1.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FileAttributeItem;

@interface FileTableViewCell : UITableViewCell

@property (nonatomic, strong) FileAttributeItem *fileModel;

@end

