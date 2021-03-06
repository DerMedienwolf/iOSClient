//
//  Instance.h
//  ARIS
//
//  Created by David Gagnon on 4/1/09.
//  Copyright 2009 University of Wisconsin - Madison. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InstantiableProtocol.h"

@interface Instance : NSObject
{
  long instance_id;
  NSString *object_type;
  long object_id;
  NSString *owner_type;
  long owner_id;
  long qty;
  BOOL infinite_qty;
  long factory_id;
  NSDate *created;
}

@property (nonatomic, assign) long instance_id;
@property (nonatomic, strong) NSString *object_type;
@property (nonatomic, assign) long object_id;
@property (nonatomic, strong) NSString *owner_type;
@property (nonatomic, assign) long owner_id;
@property (nonatomic, assign) long qty;
@property (nonatomic, assign) BOOL infinite_qty;
@property (nonatomic, assign) long factory_id;
@property (nonatomic, strong) NSDate *created;

- (id) initWithDictionary:(NSDictionary *)dict;
- (NSString *) serialize;
- (void) mergeDataFromInstance:(Instance *)i;
- (Instance *) copy;

- (id<InstantiableProtocol>) object;
- (NSString *) name;
- (long) icon_media_id;

@end

