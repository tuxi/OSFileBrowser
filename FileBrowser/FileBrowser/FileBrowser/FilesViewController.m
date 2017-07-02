//
//  FilesViewController.m
//  FileBrowser
//
//  Created by Ossey on 2017/6/30.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FilesViewController.h"
#import "FileTableViewCell.h"
#import "NSObject+IvarList.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark *** FilesViewController ***

@interface FilePreviewViewController : UIViewController {
    UITextView *_textView;
    UIImageView *_imageView;
}

+ (BOOL)canHandleExtension:(NSString *)fileExt;
- (instancetype)initWithFile:(NSString *)file;

@end


@implementation FilesViewController

////////////////////////////////////////////////////////////////////////
#pragma mark - Initialize
////////////////////////////////////////////////////////////////////////

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        
        self.path = path;
        _displayHiddenFiles = NO;
        [self loadFile:path];
        
    }
    return self;
}

- (void)loadFile:(NSString *)path {
    NSError *error = nil;
    NSArray *tempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        NSLog(@"Error: %@", error);
    }
    self.files = [self sortedFiles:tempFiles];
    if (!_displayHiddenFiles) {
       self.files = [self removeHiddenFilesFromFiles:self.files];
    }
}

- (void)setDisplayHiddenFiles:(BOOL)displayHiddenFiles {
    if (_displayHiddenFiles == displayHiddenFiles) {
        return;
    }
    _displayHiddenFiles = displayHiddenFiles;
    [self loadFile:self.path];
    
}

- (NSArray *)removeHiddenFilesFromFiles:(NSArray *)files {
    NSIndexSet *indexSet = [files indexesOfObjectsPassingTest:^BOOL(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj hasPrefix:@"."];
    }];
    NSMutableArray *tempFiles = [self.files mutableCopy];
    [tempFiles removeObjectsAtIndexes:indexSet];
    return tempFiles;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self.path lastPathComponent];
    UIBarButtonItem *rightBarButton1 = [[UIBarButtonItem alloc] initWithTitle:@"Reload" style:UIBarButtonItemStyleDone target:self action:@selector(reloadFiles)];
    self.navigationItem.rightBarButtonItems = @[rightBarButton1];
}
- (void)reloadFiles {
    [self loadFile:self.path];
    [self.tableView reloadData];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDataSource
////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([FileTableViewCell class])];
    if (cell == nil) {
        cell = [[FileTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:NSStringFromClass([FileTableViewCell class])];
    }
    
    cell.path = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"more operation" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"share" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
         NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:newPath.lastPathComponent];
        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtPath:newPath toPath:tmpPath error:&error];
        
        if (error) {
            NSLog(@"ERROR: %@", error);
        }
        UIActivityViewController *shareActivity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tmpPath]] applicationActivities:nil];
        
        shareActivity.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        };
        [self.navigationController presentViewController:shareActivity animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"info" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSDictionary *fileAtt = [[NSFileManager defaultManager] attributesOfItemAtPath:newPath error:nil];
    
        NSMutableString *attstring = @"".mutableCopy;
        [fileAtt enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key isEqualToString:NSFileSize]) {
            }
            [attstring appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
        }];
        
        [[[UIAlertView alloc] initWithTitle:@"File info" message:attstring delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil] show];
        
    }]];
    [self presentViewController:alert animated:YES completion:nil];

    
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    
    if (fileExists) {
        if (isDirectory) {
            FilesViewController *vc = [[FilesViewController alloc] initWithPath:newPath];
            [self.navigationController showViewController:vc sender:self];
        } else if ([FilePreviewViewController canHandleExtension:[newPath pathExtension]]) {
            FilePreviewViewController *preview = [[FilePreviewViewController alloc] initWithFile:newPath];
            preview.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClick)];
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        } else {
            QLPreviewController *preview = [[QLPreviewController alloc] init];
            preview.dataSource = self;
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        }
    }
}

- (void)backButtonClick {
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDelegate
////////////////////////////////////////////////////////////////////////

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *currentPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:currentPath error:&error];
    if (error) {
        [[[UIAlertView alloc] initWithTitle:@"Remove error" message:nil delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil] show];
    }
    [self reloadFiles];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"delete";
}

////////////////////////////////////////////////////////////////////////
#pragma mark - QLPreviewControllerDataSource
////////////////////////////////////////////////////////////////////////

- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item {
    
    return YES;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger) index {
    NSLog(@"index: %ld", self.tableView.indexPathForSelectedRow.row);
    // self.tableView.indexPathForSelectedRow 获取当前选中的IndexPath,
    // 注意: 当设置了[tableView deselectRowAtIndexPath:indexPath animated:YES]后，indexPathForSelectedRow为初始值
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[self.tableView.indexPathForSelectedRow.row]];
    
    return [NSURL fileURLWithPath:newPath];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Sorted files
////////////////////////////////////////////////////////////////////////
- (NSArray *)sortedFiles:(NSArray *)files {
    return [files sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(NSString* file1, NSString* file2) {
        NSString *newPath1 = [self.path stringByAppendingPathComponent:file1];
        NSString *newPath2 = [self.path stringByAppendingPathComponent:file2];
        
        BOOL isDirectory1, isDirectory2;
        [[NSFileManager defaultManager ] fileExistsAtPath:newPath1 isDirectory:&isDirectory1];
        [[NSFileManager defaultManager ] fileExistsAtPath:newPath2 isDirectory:&isDirectory2];
        
        if (isDirectory1 && !isDirectory2) {
            return NSOrderedDescending;
        }
        
        return  NSOrderedAscending;
    }];
}


@end

#pragma mark *** FilePreviewViewController ***

@implementation FilePreviewViewController

////////////////////////////////////////////////////////////////////////
#pragma mark - initialize
////////////////////////////////////////////////////////////////////////

- (instancetype)initWithFile:(NSString *)file {
    self = [super init];
    if (self) {
        
        _textView = [[UITextView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _textView.editable = NO;
        _textView.backgroundColor = [UIColor whiteColor];
        
        _imageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        _imageView.backgroundColor = [UIColor whiteColor];
        
        [self loadFile:file];
        
    }
    return self;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Other
////////////////////////////////////////////////////////////////////////

+ (BOOL)canHandleExtension:(NSString *)fileExtension {
    return ([fileExtension.lowercaseString isEqualToString:@"plist"] || [fileExtension.lowercaseString isEqualToString:@"strings"] || [fileExtension.lowercaseString isEqualToString:@"xcconfig"]);
}

- (void)loadFile:(NSString *)file {
    if ([file.pathExtension.lowercaseString isEqualToString:@"plist"] || [file.pathExtension.lowercaseString isEqualToString:@"strings"]) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:file];
        [_textView setText:[d description]];
        self.view = _textView;
    } else if ([file.pathExtension.lowercaseString isEqualToString:@"xcconfig"]) {
        NSString *d = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        [_textView setText:d];
        self.view = _textView;
    } else {
        _imageView.image = [UIImage imageWithContentsOfFile:file];
        self.view = _imageView;
    }
    
    self.title = file.lastPathComponent;
}

@end
