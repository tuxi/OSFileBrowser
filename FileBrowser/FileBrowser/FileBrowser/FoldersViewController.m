//
//  FoldersViewController.m
//  FileBrowser
//
//  Created by Ossey on 2017/6/30.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FoldersViewController.h"
#import "FileTableViewCell.h"
#import "NSObject+IvarList.h"
#import "MonitorFileChangeHelper.h"
#import "FileAttributeItem.h"
#import "NSString+FileExtend.h"

static void * FileProgressObserverContext = &FileProgressObserverContext;

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark *** FoldersViewController ***

@interface FilePreviewViewController : UIViewController {
    UITextView *_textView;
    UIImageView *_imageView;
}

@property (nonatomic, copy) NSString *filePath;

+ (BOOL)canHandleExtension:(NSString *)fileExt;
- (instancetype)initWithFile:(NSString *)file;

@end

#ifdef __IPHONE_9_0
@interface FoldersViewController () <UIViewControllerPreviewingDelegate>
#else
@interface FoldersViewController ()
#endif

@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;
@property (nonatomic, copy) void (^longPressCallBack)(NSIndexPath *indexPath);
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *selectorButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, copy) NSString *selectorFilenNewName;
@property (nonatomic, strong) NSProgress *fileProgress;
@property (nonatomic, strong) MonitorFileChangeHelper *currentFolderHelper;
@property (nonatomic, strong) MonitorFileChangeHelper *documentFolderHelper;
@property (nonatomic, strong) NSOperationQueue *loadFileQueue;

@end

@implementation FoldersViewController


////////////////////////////////////////////////////////////////////////
#pragma mark - Initialize
////////////////////////////////////////////////////////////////////////

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        self.path = path;
        _displayHiddenFiles = NO;
        self.title = [self.path lastPathComponent];
        _loadFileQueue = [NSOperationQueue new];
        UIButton *selectorBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
        self.selectorButton = selectorBtn;
        [selectorBtn setTitle:@"add" forState:UIControlStateNormal];
        [selectorBtn setTitleColor:[UIColor redColor]
                          forState:UIControlStateNormal];
        [selectorBtn sizeToFit];
        [selectorBtn addTarget:self
                        action:@selector(chooseSandBoxDocumentFiles)
              forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *rightBarButton2 = [[UIBarButtonItem alloc] initWithCustomView:selectorBtn];
        self.navigationItem.rightBarButtonItems = @[rightBarButton2];
        _fileProgress = [NSProgress progressWithTotalUnitCount:0];
        [_fileProgress addObserver:self
                        forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                           options:NSKeyValueObservingOptionInitial
                           context:FileProgressObserverContext];
        
        _currentFolderHelper = [MonitorFileChangeHelper new];
        __weak typeof(self) weakSelf = self;
        [_currentFolderHelper watcherForPath:self.path block:^(NSInteger type) {
            [weakSelf reloadFiles];
        }];
        NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (![self.path isEqualToString:documentPath]) {
            _documentFolderHelper = [MonitorFileChangeHelper new];
            [_documentFolderHelper watcherForPath:documentPath block:^(NSInteger type) {
                [weakSelf reloadFiles];
            }];
        }
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    __weak typeof(self) weakSelf = self;
    [self loadFile:self.path completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self check3DTouch];
    self.pathLabel.text = self.path;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)setupUI {
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.pathLabel];
    [self.view addSubview:self.progressBar];
    self.pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    NSDictionary *viewsDictionary = @{@"pathLabel" : self.pathLabel, @"tableView": self.tableView, @"progressBar": self.progressBar};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[tableView]|" options:NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllRight metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView]|" options:kNilOptions metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[pathLabel]-10-|" options:NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllRight metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[pathLabel]|" options:kNilOptions metrics:nil views:viewsDictionary]];
    
    CGFloat progressBarTopConst = 0.0;
    if (!self.navigationController.isNavigationBarHidden) {
        progressBarTopConst = 64.0;
    }
    NSDictionary *metricsDictionary = @{@"progressBarTopConst" : [NSNumber numberWithFloat:progressBarTopConst]};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[progressBar]|" options:NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllRight metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-progressBarTopConst-[progressBar]" options:kNilOptions metrics:metricsDictionary views:viewsDictionary]];
}


- (void)setSelectorMode:(BOOL)selectorMode {
    if (_selectorMode == selectorMode) {
        return;
    }
    _selectorMode = selectorMode;
    if (selectorMode) {
        if (self.selectorFiles.count > 0) {
            [self.selectorFiles removeAllObjects];
        }
        UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.deleteButton = deleteButton;
        [deleteButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [deleteButton setTitle:@"delete" forState:UIControlStateNormal];
        [deleteButton sizeToFit];
        [deleteButton addTarget:self action:@selector(deleteFileFromSelectorFiles) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *rightBarButton1 = [[UIBarButtonItem alloc] initWithCustomView:deleteButton];
        
        [self.selectorButton setTitle:@"ok" forState:UIControlStateNormal];
        UIBarButtonItem *rightBarButton2 = [[UIBarButtonItem alloc]initWithCustomView:self.selectorButton];
        self.navigationItem.rightBarButtonItems = @[rightBarButton1, rightBarButton2];
        // 编辑模式的时候可以多选
        self.tableView.allowsMultipleSelectionDuringEditing = YES;
        
    } else {
        UIButton *selectorBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
        self.selectorButton = selectorBtn;
        [selectorBtn setTitle:@"add" forState:UIControlStateNormal];
        [selectorBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [selectorBtn sizeToFit];
        [selectorBtn addTarget:self action:@selector(chooseSandBoxDocumentFiles) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *rightBarButton2 = [[UIBarButtonItem alloc] initWithCustomView:selectorBtn];
        self.navigationItem.rightBarButtonItems = @[rightBarButton2];
    }
    [self.tableView setEditing:selectorMode animated:YES];
    
}

- (void)loadFile:(NSString *)path completion:(void (^)())completion {
    [_loadFileQueue addOperationWithBlock:^{
        NSMutableArray *array = [NSMutableArray array];
        NSError *error = nil;
        NSArray *tempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
        if (error) {
            NSLog(@"Error: %@", error);
        }
        NSArray *files = [self sortedFiles:tempFiles];
        [files enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            FileAttributeItem *model = [FileAttributeItem new];
            NSString *fullPath = [self.path stringByAppendingPathComponent:obj];
            model.fullPath = fullPath;
            NSError *error = nil;
            NSArray *subFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fullPath error:&error];
            if (!error) {
                model.subFileCount = subFiles.count;
            }
            //            [fullPath asyncFileSize:^(unsigned long long fileSize) {
            //                model.fileSize = [NSString stringWithFormat:@"%@", [NSString transformedFileSizeValue:@(fileSize)]];
            //            }];
            [array addObject:model];
        }];
        self.files = [array copy];
        if (!_displayHiddenFiles) {
            self.files = [self removeHiddenFilesFromFiles:self.files];
        }
        if (completion) {
            completion();
        }
    }];
}

- (void)setDisplayHiddenFiles:(BOOL)displayHiddenFiles {
    if (_displayHiddenFiles == displayHiddenFiles) {
        return;
    }
    _displayHiddenFiles = displayHiddenFiles;
    __weak typeof(self) weakSelf = self;
    [self loadFile:self.path completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    }];
    
}

- (NSArray *)removeHiddenFilesFromFiles:(NSArray *)files {
    NSIndexSet *indexSet = [files indexesOfObjectsPassingTest:^BOOL(FileAttributeItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.fullPath.lastPathComponent hasPrefix:@"."];
    }];
    NSMutableArray *tempFiles = [self.files mutableCopy];
    [tempFiles removeObjectsAtIndexes:indexSet];
    return tempFiles;
    
}


- (void)reloadFiles {
    __weak typeof(self) weakSelf = self;
    [self loadFile:self.path completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    }];
    
}

- (void)deleteFileFromSelectorFiles {
    [self.selectorFiles enumerateObjectsUsingBlock:^(FileAttributeItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *fullPath = obj.fullPath;
        NSError *removeError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&removeError];
        if (removeError) {
            NSLog(@"Error: remove error[%@]", removeError.localizedDescription);
        }
    }];
}

- (void)chooseSandBoxDocumentFiles {
    __weak typeof(self) weakSelf = self;
    if ([self.selectorButton.currentTitle isEqualToString:@"add"]) {
        // 跳转到沙盒document目录下的文件，并将选择的文件copy到当前目录下
        FoldersViewController *vc = [[FoldersViewController alloc] initWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject];
        vc.selectorMode = YES;
        [self.navigationController showViewController:vc sender:self];
        
        vc.selectorFilsCompetionHandler = ^(NSArray *paths) {
            
            [weakSelf copyFileFromPaths:paths];
        };
    } else {
        
        
        NSMutableArray *selectorFiles = [NSMutableArray arrayWithCapacity:self.selectorFiles.count];
        [self.selectorFiles enumerateObjectsUsingBlock:^(FileAttributeItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *fullPath = obj.fullPath;
            [selectorFiles addObject:fullPath];
        }];
        
        
        [self.navigationController popViewControllerAnimated:YES];
        
        if (self.selectorFilsCompetionHandler) {
            void (^selectorFilsCompetionHandler)(NSArray *paths) = self.selectorFilsCompetionHandler;
            self.selectorFilsCompetionHandler = nil;
            selectorFilsCompetionHandler(selectorFiles);
        }
    }
    
}


- (void)resetProgress {
    BOOL hasActiveFlag = [self selectorFiles].count;
    if (hasActiveFlag == NO) {
        @try {
            [self.fileProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
        } @catch (NSException *exception) {
            NSLog(@"Error: Repeated removeObserver(keyPath = fractionCompleted)");
        } @finally {
            
        }
        
        self.fileProgress = [NSProgress progressWithTotalUnitCount:0];
        [self.fileProgress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionInitial
                               context:FileProgressObserverContext];
    }
}

- (void)copyFileFromPaths:(NSArray<NSString *> *)paths {
    [_loadFileQueue addOperationWithBlock:^{
        [self resetProgress];
        self.fileProgress.totalUnitCount+=paths.count;
        __weak typeof(self) weakSelf = self;
        [paths enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSString *desPath = [weakSelf.path stringByAppendingPathComponent:[obj lastPathComponent]];
            if ([desPath isEqualToString:obj]) {
                NSLog(@"路径相同");
                return;
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:desPath]) {
                UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"源文件夹存在相同文件，是否替换" message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    
                    NSError *removeError = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:desPath error:&removeError];
                    if (!removeError) {
                        NSError *error = nil;
                        [[NSFileManager defaultManager] copyItemAtPath:obj toPath:desPath error:&error];
                        if (error) {
                            NSLog(@"%@", error.localizedDescription);
                        }
                    } else {
                        NSLog(@"%@", removeError.localizedDescription);
                    }
                    weakSelf.fileProgress.completedUnitCount++;
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"no" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    weakSelf.fileProgress.completedUnitCount++;
                }]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
            } else {
                NSError *error = nil;
                [[NSFileManager defaultManager] copyItemAtPath:obj toPath:desPath error:&error];
                if (error) {
                    NSLog(@"%@", error.localizedDescription);
                }
                weakSelf.fileProgress.completedUnitCount++;
            }
        }];
    }];
    
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
#pragma mark - Progress
////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == FileProgressObserverContext && object == self.fileProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressBar.progress = [object fractionCompleted];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - 3D Touch Delegate
////////////////////////////////////////////////////////////////////////

#ifdef __IPHONE_9_0
- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    // 需要将location在self.view上的坐标转换到tableView上，才能从tableView上获取到当前indexPath
    CGPoint targetLocation = [self.view convertPoint:location toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:targetLocation];
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
    
    cell.fileModel = self.files[indexPath.row];
    
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
    
    if (self.selectorMode == YES) {
        [self.selectorFiles addObject:self.files[indexPath.row]];
    } else {
        self.indexPath = indexPath;
        UIViewController *vc = [self previewControllerByIndexPath:indexPath];
        [self jumpToDetailControllerToViewController:vc atIndexPath:indexPath];
    }
}

//- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (self.selectorMode) {
//        return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
//    } else {
//        return UITableViewCellEditingStyleNone;
//    }
//}


- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath{
    //从选中中取消
    if (self.selectorFiles.count > 0) {
        [self.selectorFiles removeObject:self.files[indexPath.row]];
    }
    
}

- (void)jumpToDetailControllerToViewController:(UIViewController *)viewController atIndexPath:(NSIndexPath *)indexPath {
    NSString *newPath = self.files[indexPath.row].fullPath;
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    if (fileExists) {
        if (isDirectory) {
            FoldersViewController *vc = (FoldersViewController *)viewController;
            [self.navigationController showViewController:vc sender:self];
        } else if ([FilePreviewViewController canHandleExtension:[newPath pathExtension]]) {
            FilePreviewViewController *preview = (FilePreviewViewController *)viewController;
            preview.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClick)];
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        } else {
            QLPreviewController *preview = (QLPreviewController *)viewController;
            preview.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClick)];
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        }
    }
}


- (UIViewController *)previewControllerByIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath || !self.files.count) {
        return nil;
    }
    NSString *newPath = self.files[indexPath.row].fullPath;
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    UIViewController *vc = nil;
    if (fileExists) {
        if (isDirectory) {
            vc = [[FoldersViewController alloc] initWithPath:newPath];
            
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

- (void)deleteFileAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.files.count) {
        return;
    }
    NSString *currentPath = self.files[indexPath.row].fullPath;
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:currentPath error:&error];
    if (error) {
        [[[UIAlertView alloc] initWithTitle:@"Remove error" message:nil delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil] show];
    }
    //    [self reloadFiles];
    NSMutableArray *arr = self.files.mutableCopy;
    [arr removeObjectAtIndex:indexPath.row];
    self.files = arr;
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)selectorAll {
    if (self.selectorFiles.count) {
        [self.selectorFiles removeAllObjects];
    }
    for (int i = 0; i < self.files.count; i++) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
        UITableViewCell *cell = (UITableViewCell *)[self.tableView cellForRowAtIndexPath:path];
        cell.selected = YES;
        [self.selectorFiles addObject:self.files[i]];//添加到选中列表
        
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDelegate
////////////////////////////////////////////////////////////////////////

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
//    [self deleteFileAtIndexPath:indexPath];
//}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"delete";
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewRowAction *changeAction = [UITableViewRowAction rowActionWithStyle:(UITableViewRowActionStyleDefault) title:@"rename" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"rename" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"请输入需要修改的名字";
            [textField addTarget:self action:@selector(alertViewTextFieldtextChange:) forControlEvents:UIControlEventEditingChanged];
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
            if ([self.selectorFilenNewName containsString:@"/"]) {
                NSLog(@"文件名称不符合");
                return;
            }
            
            NSString *currentPath = self.files[indexPath.row].fullPath;
            NSString *newPath = [self.path stringByAppendingPathComponent:self.selectorFilenNewName];
            BOOL res = [[NSFileManager defaultManager] fileExistsAtPath:newPath];
            if (res) {
                NSLog(@"存在同名的文件");
                return;
            }
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:currentPath toPath:newPath error:&moveError];
            if (!moveError) {
                NSMutableArray *files = [self.files mutableCopy];
                [files replaceObjectAtIndex:indexPath.row withObject:self.selectorFilenNewName];
                self.files = files;
                [tableView reloadData];
            } else {
                NSLog(@"%@", moveError.localizedDescription);
            }
            self.selectorFilenNewName = nil;
            
        }]];
        [self presentViewController:alert animated:true completion:nil];
        [tableView reloadData];
    }];
    changeAction.backgroundColor = [UIColor orangeColor];
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:(UITableViewRowActionStyleDefault) title:@"delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确定删除吗" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self deleteFileAtIndexPath:indexPath];
        }]];
        [self presentViewController:alert animated:true completion:nil];
    }];
    deleteAction.backgroundColor = [UIColor redColor];
    return @[changeAction,deleteAction];
}

- (void)alertViewTextFieldtextChange:(UITextField *)tf {
    self.selectorFilenNewName = tf.text;
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
    NSString *newPath = self.files[self.indexPath.row].fullPath;
    
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
            return NSOrderedAscending;
        }
        
        return  NSOrderedDescending;
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
    NSString *newPath = self.files[self.indexPath.row].fullPath;
    NSDictionary *fileAtt = [[NSFileManager defaultManager] attributesOfItemAtPath:newPath error:nil];
    
    NSMutableString *attstring = @"".mutableCopy;
    [fileAtt enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:NSFileSize]) {
            obj = [NSString transformedFileSizeValue:obj];
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
    NSString *newPath = self.files[self.indexPath.row].fullPath;
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

////////////////////////////////////////////////////////////////////////
#pragma mark - Lazy
////////////////////////////////////////////////////////////////////////

- (UILabel *)pathLabel {
    if (!_pathLabel) {
        _pathLabel = [[UILabel alloc] init];
        _pathLabel.numberOfLines = 0;
        _pathLabel.textColor = [UIColor grayColor];
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_4) {
            _pathLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:1.0];
        } else {
            _pathLabel.font = [UIFont systemFontOfSize:12];
        }
    }
    return _pathLabel;
}

- (UIProgressView *)progressBar {
    if (!_progressBar) {
        _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressBar.progress = 0.0;
    }
    return _progressBar;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

- (NSMutableArray<FileAttributeItem *> *)selectorFiles {
    if (!_selectorFiles) {
        _selectorFiles = [NSMutableArray array];
    }
    return _selectorFiles;
}

- (void)dealloc {
    [_loadFileQueue cancelAllOperations];
    [_fileProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
    _fileProgress = nil;
    NSLog(@"%s", __func__);
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

