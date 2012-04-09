#import "CPResourcefulManagedObject.h"
#import "NSManagedObject+CocoaPlant.h"

@implementation CPResourcefulManagedObject

+ (id)updateOrInsertWithDictionary:(NSDictionary *)dictionary
                     dictionaryKey:(NSString *)dictionaryKey
                     attributeName:(NSString *)attributeName
            inManagedObjectContext:(NSManagedObjectContext *)context {
    // Fetch with the ID Key.
    id fetchedObject = [self fetchFirstInManagedObjectContext:context error:NULL options:^(NSFetchRequest *request) {
        request.fetchBatchSize = 20;
        request.returnsObjectsAsFaults = NO;
        request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", attributeName, [dictionary objectForKey:dictionaryKey]];
    }];

    if (!fetchedObject) {
        fetchedObject = [self insertIntoManagedObjectContext:context];
    }

    [fetchedObject updateWithDictionary:dictionary];
    return fetchedObject;
}

// TODO: Test!
+ (void)updateAllWithArray:(NSArray *)servedDictionaries
                   keyPath:(NSString *)keyPath
             attributeName:(NSString *)attributeName
             dictionaryKey:(NSString *)dictionaryKey
      managedObjectContext:(NSManagedObjectContext *)context {
    [self updateAllWithArray:servedDictionaries keyPath:keyPath attributeName:attributeName relationshipKeyPaths:nil dictionaryKey:dictionaryKey managedObjectContext:context];
}

// TODO: Test!
+ (void)updateAllWithArray:(NSArray *)servedDictionaries
                   keyPath:(NSString *)keyPath
             attributeName:(NSString *)attributeName
      relationshipKeyPaths:(NSArray *)relationshipKeyPaths
             dictionaryKey:(NSString *)dictionaryKey
      managedObjectContext:(NSManagedObjectContext *)context {

    // Create sets of all servedIDs & fetchedIDs.
    NSArray *servedIDs = [servedDictionaries valueForKeyPath:keyPath];
    if ([servedIDs count] == 0) return;
    NSMutableSet *servedIDsSet = [NSMutableSet setWithArray:servedIDs];
    NSArray *fetchedObjects = // TODO: handle fetch error.
    [self fetchInManagedObjectContext:context error:NULL options:^(NSFetchRequest *request) {
        request.fetchBatchSize = 20;
        request.returnsObjectsAsFaults = NO;
        request.relationshipKeyPathsForPrefetching = relationshipKeyPaths;
        request.predicate = [NSPredicate predicateWithFormat:@"%K IN %@",
                             attributeName, servedIDsSet];
    }];
    NSSet *fetchedIDsSet = [NSSet setWithArray:[fetchedObjects valueForKeyPath:attributeName]];
    
    // Insert newServedDictionaries (served - fetched).
    NSMutableSet *newServedIDsSet = [NSMutableSet setWithSet:servedIDsSet];
    [newServedIDsSet minusSet:fetchedIDsSet];
    NSPredicate *dictionaryPredicate = [NSPredicate predicateWithFormat:@"%K IN %@",
                                        dictionaryKey, newServedIDsSet];
    NSArray *newServedDictionaries = [servedDictionaries
                                      filteredArrayUsingPredicate:dictionaryPredicate];
    for (NSDictionary *dictionary in newServedDictionaries) {
        CPResourcefulManagedObject *resource = [self insertIntoManagedObjectContext:context];
        [resource updateWithDictionary:dictionary];
    }

    // Update oldFetchedObjects (served & fetched).
    [servedIDsSet intersectSet:fetchedIDsSet];
    dictionaryPredicate = [NSPredicate predicateWithFormat:@"%K IN %@",
                           dictionaryKey, servedIDsSet];
    NSPredicate *objectPredicate = [NSPredicate predicateWithFormat:@"%K IN %@",
                                    attributeName, servedIDsSet];
    NSArray *oldServedDictionaries = [servedDictionaries
                                      filteredArrayUsingPredicate:dictionaryPredicate];
    NSArray *oldFetchedObjects = [fetchedObjects filteredArrayUsingPredicate:objectPredicate];
    
    // Sort both arrays by object ID so that they're in sync for iteration below.
    NSArray *dictionarySortDescriptors = [NSArray arrayWithObject:
                                          [NSSortDescriptor sortDescriptorWithKey:dictionaryKey
                                                                        ascending:YES]];
    NSArray *objectSortDescriptors = [NSArray arrayWithObject:
                                      [NSSortDescriptor sortDescriptorWithKey:attributeName
                                                                    ascending:YES]];
    oldServedDictionaries = [oldServedDictionaries
                             sortedArrayUsingDescriptors:dictionarySortDescriptors];
    oldFetchedObjects = [oldFetchedObjects sortedArrayUsingDescriptors:objectSortDescriptors];
    
    [oldFetchedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //        @try {
        // TODO: Fix bug. objectAtIndex 4 beyond bounds 0-3.
        [obj updateWithDictionary:[oldServedDictionaries objectAtIndex:idx]];
        //        }
        //        @catch (NSException *exception) {
        //            // TODO: Notify user & server that the server response was bad.
        //            DLog(@"derp! updateWithDictionary error: %@", exception);
        //        }
    }];
}

- (BOOL)updateWithDictionary:(NSDictionary *)dictionary { return YES; }

@end
