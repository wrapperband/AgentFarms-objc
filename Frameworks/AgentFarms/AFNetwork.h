/** AFNetwork

    Copyright (c) 2003 Stefan Urbanek

    Written by: Stefan Urbanek <urbanek@host.sk>
    Date: 2003 Sep 20
   
    This file is part of the XY Framework.
 
    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.
 
    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.
 
    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 
 */

#import <Foundation/NSObject.h>

@class NSMutableSet;
@class NSSet;
@class NSMutableArray;
@class AFNetworkLink;

@interface AFNetwork:NSObject
{
    Class           linkClass;
    NSMutableSet   *objects;
    NSMutableArray *links;
}
- (void)addObject:(id)anObject;
- (void)addObjects:(NSArray *)array;
- (void)removeObject:(id)anObject;
- (void)removeObjects:(NSArray *)array;
- (BOOL)containsObject:(id)anObject;
- (NSSet *)objects;
- (AFNetworkLink *)linkObject:(id)anObject withObject:(id)anotherObject;
- (void)unlinkObject:(id)anObject withObject:(id)anotherObject;

- (NSArray *)links;
- (NSArray *)linksWithObject:(id)anObject;
- (NSArray *)linksWithDestinationObject:(id)anObject;
- (NSArray *)linksWithSourceObject:(id)anObject;

- (void)setLinkClass:(Class)aClass;
- (Class)linkClass;
@end
