//
//  DataTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/20/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "DataTableViewController.h"
#import "TestRecord.h"
#import "TestRecordViewController.h"

@interface DataTableViewController ()

@end

@implementation DataTableViewController {
    NSArray* testRecords;
    TestRecord* selectedRecord;
}

@synthesize cslContext;
@synthesize managedObjectContext;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Listen for connection events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDidConnect:)
                                                 name:@"bleDidConnect" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDidDisconnect:)
                                                 name:@"bleDidDisconnect" object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (int)countTestRecords
{
    // Sync test records
    NSError *error;
    
    NSString *sortKey = @"created";
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Query all TestRecords from CoreData
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"TestRecord"
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    testRecords = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    return (int)testRecords.count;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int recordCount = [self countTestRecords];
    return recordCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DataCell"];
    
    // Configure Cell
    UILabel *mainLabel = (UILabel *)[cell.contentView viewWithTag:5];
    UILabel *detailLabel = (UILabel *)[cell.contentView viewWithTag:6];
    
    TestRecord* record = [testRecords objectAtIndex:indexPath.row];
    
    mainLabel.text = record.simpleTestID;
    detailLabel.text = record.patientNIHID;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedRecord = [testRecords objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"ShowRecord" sender:self];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowRecord"]) {
        TestRecordViewController* vc = (TestRecordViewController*)segue.destinationViewController;
        vc.managedObjectContext = managedObjectContext;
        vc.cslContext = cslContext;
        vc.testRecord = selectedRecord;
    }
}


@end
