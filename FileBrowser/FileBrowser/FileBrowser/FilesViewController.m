//
//  FilesViewController.m
//  FileBrowser
//
//  Created by Ossey on 2017/6/30.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "FilesViewController.h"

@interface FilePreviewViewController : UIViewController {
    UITextView *textView;
    UIImageView *imageView;
}



+(BOOL)canHandleExtension:(NSString *)fileExt;
- (instancetype)initWithFile:(NSString *)file;
@end


@implementation FilesViewController

- (id)initWithPath:(NSString *)path
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        
        self.path = path;
        
        self.title = [path lastPathComponent];
        
        NSError *error = nil;
        NSArray *tempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
        
        if (error)
        {
            NSLog(@"ERROR: %@", error);
            
            if ([path isEqualToString:@"/System"])
                tempFiles = @[@"Library"];
            
            if ([path isEqualToString:@"/Library"])
                tempFiles = @[@"Preferences"];
            
            if ([path isEqualToString:@"/var"])
                tempFiles = @[@"mobile"];
            
            if ([path isEqualToString:@"/usr"])
                tempFiles = @[@"lib", @"libexec", @"bin"];
        }
        
        self.files = [tempFiles sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(NSString* file1, NSString* file2) {
            NSString *newPath1 = [self.path stringByAppendingPathComponent:file1];
            NSString *newPath2 = [self.path stringByAppendingPathComponent:file2];
            
            BOOL isDirectory1, isDirectory2;
            [[NSFileManager defaultManager ] fileExistsAtPath:newPath1 isDirectory:&isDirectory1];
            [[NSFileManager defaultManager ] fileExistsAtPath:newPath2 isDirectory:&isDirectory2];
            
            if (isDirectory1 && !isDirectory2)
                return NSOrderedDescending;
            
            return  NSOrderedAscending;
        }];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    if (!fileExists) {
        return cell;
    }
    cell.textLabel.text = self.files[indexPath.row];
    
    if (isDirectory)
        cell.imageView.image = [UIImage imageNamed:@"Folder"];
    else if ([[newPath pathExtension] isEqualToString:@"png"])
        cell.imageView.image = [UIImage imageNamed:@"Picture"];
    else
        cell.imageView.image = nil;
    
#if 0
    if (fileExists && !isDirectory)
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
#endif
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:newPath.lastPathComponent];
    
    NSError *error = nil;
    
    [[NSFileManager defaultManager] copyItemAtPath:newPath toPath:tmpPath error:&error];
    
    if (error)
        NSLog(@"ERROR: %@", error);
    
    UIActivityViewController *shareActivity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tmpPath]] applicationActivities:nil];
    
    shareActivity.completionHandler = ^(NSString *activityType, BOOL completed){
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        
    };
    
    UIViewController *vc = [[UIViewController alloc] init];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
    nc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    
    [self.navigationController presentViewController:nc animated:YES completion:^{
        
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[indexPath.row]];
    
    
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager ] fileExistsAtPath:newPath isDirectory:&isDirectory];
    
    
    if (fileExists)
    {
        if (isDirectory)
        {
            FilesViewController *vc = [[FilesViewController alloc] initWithPath:newPath];
            [self.navigationController showViewController:vc sender:self];
        }
        else if ([FilePreviewViewController canHandleExtension:[newPath pathExtension]])
        {
            FilePreviewViewController *preview = [[FilePreviewViewController alloc] initWithFile:newPath];
            
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        }
        else
        {
            QLPreviewController *preview = [[QLPreviewController alloc] init];
            preview.dataSource = self;
            
            UINavigationController *detailNavController = [[UINavigationController alloc] initWithRootViewController:preview];
            
            [self.navigationController showDetailViewController:detailNavController sender:self];
        }
    }
}

#pragma mark - QuickLook

- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item {
    
    return YES;
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller {
    return 1;
}

- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index {
    
    NSString *newPath = [self.path stringByAppendingPathComponent:self.files[self.tableView.indexPathForSelectedRow.row]];
    
    return [NSURL fileURLWithPath:newPath];
}

@end


@implementation FilePreviewViewController

- (instancetype)initWithFile:(NSString *)file
{
    self = [super init];
    if (self) {
        
        textView = [[UITextView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        textView.editable = NO;
        textView.backgroundColor = [UIColor whiteColor];
        
        imageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        imageView.backgroundColor = [UIColor whiteColor];
        
        [self loadFile:file];
        
    }
    return self;
}

+(BOOL)canHandleExtension:(NSString *)fileExt
{
    if (UI_USER_INTERFACE_IDIOM() != 4) // Don't use QuickLook for images on watchOS
        return ([fileExt isEqualToString:@"plist"] || [fileExt isEqualToString:@"strings"] || [fileExt isEqualToString:@"xcconfig"] );
    
    return ([fileExt isEqualToString:@"plist"] || [fileExt isEqualToString:@"strings"] || [fileExt isEqualToString:@"png"] || [fileExt isEqualToString:@"xcconfig"] );
}

-(void)loadFile:(NSString *)file
{
    if ([file.pathExtension isEqualToString:@"plist"] || [file.pathExtension isEqualToString:@"strings"])
    {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:file];
        [textView setText:[d description]];
        self.view = textView;
    }
    else if ([file.pathExtension isEqualToString:@"xcconfig"])
    {
        NSString *d = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        [textView setText:d];
        self.view = textView;
    }
    else
    {
        imageView.image = [UIImage imageWithContentsOfFile:file];
        self.view = imageView;
    }
    
    self.title = file.lastPathComponent;
}

@end
