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

@property (nonatomic, copy) NSString *filePath;

+ (BOOL)canHandleExtension:(NSString *)fileExt;
- (instancetype)initWithFile:(NSString *)file;

@end

#ifdef __IPHONE_9_0
@interface FilesViewController () <UIViewControllerPreviewingDelegate>
#else
@interface FilesViewController ()
#endif

@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;
@property (nonatomic, copy) void (^longPressCallBack)(NSIndexPath *indexPath);
@property (nonatomic, strong) NSIndexPath *indexPath;

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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self check3DTouch];
}

- (void)reloadFiles {
    [self loadFile:self.path];
    [self.tableView reloadData];
}

- (void)check3DTouch {
    /// 检测是否有3d touch 功能
    if ([self respondsToSelector:@selector(traitCollection)]) {
        if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
            if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
                // 支持3D Touch
                if ([self respondsToSelector:@selector(registerForPreviewingWithDelegate:sourceView:)]) {
                    [self registerForPreviewingWithDelegate:self sourceView:self.view];
                    self.longPress.enabled = NO;
                }
            } else {
                // 不支持3D Touch
                self.longPress.enabled = YES;
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - 3D Touch Delegate
////////////////////////////////////////////////////////////////////////

#ifdef __IPHONE_9_0
- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    _indexPath = indexPath;
    UIViewController *vc = [self previewControllerByIndexPath:indexPath];
    // 预览区域大小(可不设置)
    vc.preferredContentSize = CGSizeMake(0, 320);
    return vc;
}



- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self showViewController:viewControllerToCommit sender:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    
    [self check3DTouch];
}

#endif


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
    
    self.indexPath = indexPath;
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"more operation" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"share" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self shareAction];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"info" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
        [self infoAction];
        
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.indexPath = indexPath;
    UIViewController *vc = [self previewControllerByIndexPath:indexPath];
    [self jumpToDetailControllerToViewController:vc atIndexPath:indexPath];
}

- (void)jumpToDetailControllerToViewController:(UIViewController *)viewController atIndexPath:(NSIndexPath *)indexPath {
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    if (fileExists) {
        if (isDirectory) {
            FilesViewController *vc = (FilesViewController *)viewController;
            [self.navigationController showViewController:vc sender:self];
        } else if ([FilePreviewViewController canHandleExtension:[newPath pathExtension]]) {
            FilePreviewViewController *preview = (FilePreviewViewController *)viewController;
            preview.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClick)];
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        } else {
            QLPreviewController *preview = (QLPreviewController *)viewController;
//            preview.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClick)];
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        }
    }
}

- (UIViewController *)previewControllerByIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    UIViewController *vc = nil;
    if (fileExists) {
        if (isDirectory) {
            vc = [[FilesViewController alloc] initWithPath:newPath];
            
        } else if ([FilePreviewViewController canHandleExtension:[newPath pathExtension]]) {
            vc = [[FilePreviewViewController alloc] initWithFile:newPath];
        } else {
            QLPreviewController *preview= [[QLPreviewController alloc] init];
            preview.dataSource = self;
            vc = preview;
        }
    }
    return vc;
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
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[self.indexPath.row]];
    
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

////////////////////////////////////////////////////////////////////////
#pragma mark - Actions
////////////////////////////////////////////////////////////////////////

- (UILongPressGestureRecognizer *)longPress {
    
    if (!_longPress) {
        _longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(showPeek:)];
        [self.view addGestureRecognizer:_longPress];
    }
    return _longPress;
}

- (void)showPeek:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [longPress locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        
        if (self.longPressCallBack) {
            self.longPressCallBack(indexPath);
        }
        
        self.longPress.enabled = NO;
        UIViewController *vc = [self previewControllerByIndexPath:indexPath];
        [self jumpToDetailControllerToViewController:vc atIndexPath:indexPath];
    }
}


- (void)infoAction {
    if (!self.indexPath) {
        return;
    }
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[self.indexPath.row]];
    NSDictionary *fileAtt = [[NSFileManager defaultManager] attributesOfItemAtPath:newPath error:nil];
    
    NSMutableString *attstring = @"".mutableCopy;
    [fileAtt enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:NSFileSize]) {
        }
        [attstring appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
    }];
    
    [[[UIAlertView alloc] initWithTitle:@"File info" message:attstring delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil] show];
    self.indexPath = nil;
}

- (void)shareAction {
    if (!self.indexPath) {
        return;
    }
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[self.indexPath.row]];
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
    self.indexPath = nil;
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
        _filePath = file;
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

#ifdef __IPHONE_9_0
- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.filePath isDirectory:&isDirectory];
    if (!fileExists || isDirectory) {
        return nil;
    }
    
    UIPreviewAction *action1 = [UIPreviewAction actionWithTitle:@"info" style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        [self infoAction];
    }];
    
    UIPreviewAction *action2 = [UIPreviewAction actionWithTitle:@"share" style:UIPreviewActionStyleDestructive handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        [self shareAction];
    }];
    
    NSArray *actions = @[action1, action2];
    
    // 将所有的actions 添加到group中
    UIPreviewActionGroup *group1 = [UIPreviewActionGroup actionGroupWithTitle:@"more operation" style:UIPreviewActionStyleDefault actions:actions];
    NSArray *group = @[group1];
    
    return group;
}
#endif

- (void)infoAction {
    
    NSDictionary *fileAtt = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil];
    
    NSMutableString *attstring = @"".mutableCopy;
    [fileAtt enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:NSFileSize]) {
        }
        [attstring appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
    }];
    
    [[[UIAlertView alloc] initWithTitle:@"File info" message:attstring delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil] show];
}

- (void)shareAction {
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.filePath.lastPathComponent];
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtPath:self.filePath toPath:tmpPath error:&error];
    
    if (error) {
        NSLog(@"ERROR: %@", error);
    }
    UIActivityViewController *shareActivity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tmpPath]] applicationActivities:nil];
    
    shareActivity.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    };
    [self.navigationController presentViewController:shareActivity animated:YES completion:nil];
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

