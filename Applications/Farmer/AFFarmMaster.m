/** AFFarmController
 
    Copyright (c) 2004 Stefan Urbanek

    Written by: Stefan Urbanek
    Date: 2004 Feb 4
    
    This file is part of the Farmer application.
 
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


#import "AFFarmMaster.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSArchiver.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import <AppKit/NSButton.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSSavePanel.h>
#import <AppKit/NSStepper.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSWindow.h>

#import "AFFarm.h"
#import <AgentFarms/AFModelBundle.h>
#import <AgentFarms/AFModel.h>
#import "NSObject+NibLoading.h"
#import "AFAssistantManager.h"
#import "AFAssistantInfo.h"

@interface AFFarmMaster(Private)
- (void)_loadFarmAssistants;
- (void)_postNotificationName:(NSString *)name;
- (void)stepCountChanged:(id)sender;
- (BOOL)shouldClose;
- (void)performClose;
- (int)stepCount; /* FIXME */
@end

@implementation AFFarmMaster
- initWithModelBundle:(AFModelBundle *)modelBundle
{
    NSWindow *farmWindow;
    
    self = [super init];

    if(!modelBundle)
    {
        [NSException raise:@"AFFarmException"
                     format:@"No model bundle specified."];
        [self dealloc];
        return nil;
    }
    
    if(![self loadMyNibNamed:@"Farm"])
    {
        [NSException raise:@"AFFarmException"
                     format:@"Unable to load Farm window resources"];
        [self dealloc];
        return nil;
    }

    modelPath = RETAIN([modelBundle bundlePath]);
    farmWindow = [self window];
    
    [self createFarmFromBundle:modelBundle];

    [self _loadFarmAssistants];
    
    [self _postNotificationName:AFFarmCreatedNotification];

    /* Simulator */
    simulator = [[AFDistantSimulator alloc] init];
    
    /* Create farm window */
    [farmWindow setMinSize:NSMakeSize([farmWindow minSize].width,[farmWindow frame].size.height)];
    [farmWindow setMaxSize:NSMakeSize([farmWindow maxSize].width,[farmWindow frame].size.height)];
    [farmWindow makeKeyAndOrderFront:nil];
    [stepCountField setIntValue:[[farm model] defaultStepCount]];
    [self stepCountChanged:stepCountField];
    
    [self setFarmState:AFFarmDisconnectedState];

    [self log:@"Welcome to farm '%@'", [[farm model] name]];


    /* Register as observer */

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(simulatorDidConnect:)
               name:AFDistantSimulatorConnectedNotification
             object:simulator];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(simulatorDidDisconnect:)
               name:AFDistantSimulatorDisconnectedNotification
             object:simulator];
    
    [self connectToSimulator];

    return self;
}

- (void)dealloc
{
    RELEASE(assistants);
    RELEASE(simulator);
    RELEASE(farm);
    RELEASE(modelPath);
    
    [super dealloc];
}

- (void)_loadFarmAssistants
{
    AFAssistantManager *amanager = [AFAssistantManager sharedManager];
    NSEnumerator       *enumerator;
    AFAssistantInfo    *info;
    NSString           *name;
    
    if(assistants)
    {
        NSLog(@"Warning: Farm assistants already loaded. (ignoring)");
        return;
    }

    assistants = [[NSMutableDictionary alloc] init];

    enumerator = [[amanager availableAssistants] objectEnumerator];
    
    while( (name = [enumerator nextObject]) )
    {
        info = [amanager infoForAssistant:name];

        [assistantsView addButtonWithTitle:[info name]
                                     image:[info icon]
                         representedObject:info];

    }
}

- (void)buttonRow:(AFButtonRow *)row selectedObject:(AFAssistantInfo *)info
{
    AFAssistantManager *amanager = [AFAssistantManager sharedManager];
    AFFarmController   *assistant;

    assistant = [assistants objectForKey:[info name]];

    if(!assistant)
    {
        NSLog(@"Instantiating %@", [info name]);
        
        assistant = [amanager createAssistant:[info name] forMaster:self];
        if(!assistant)
        {
            [NSException raise:@"AFFarmMasterException"
                         reason:@"Unable to create assistant %@", [info name]];
            return;
        }
        [assistants setObject:assistant forKey:[info name]];
    }
    
    [[assistant window] makeKeyAndOrderFront:nil];
}

- (void)_postNotificationName:(NSString *)name
{
    NSLog(@"-- POST: %@", name);
    [[NSNotificationCenter defaultCenter] 
                    postNotificationName:name
                                  object:self];
}

- (void)createFarmFromBundle:(AFModelBundle *)bundle
{
    farm = [[AFFarm alloc] initWithModelBundle:bundle];
}

- (void)connectToSimulator
{
    NSLog(@"Connecting to simulator...");
    if(farmState != AFFarmDisconnectedState)
    {
        [NSException raise:@"AFFarmException"
                     format:@"Farm is not disconnected"];
        return;
    }
    
    [timeField setIntValue:0];
    [self setFarmState: AFFarmConnectingState];

    [simulator connectNew];
}

- (void)simulatorDidConnect:(NSNotification *)notif
{
    NSLog(@"Simulator did connect.");

    if(farmState != AFFarmConnectingState)
    {
        [NSException raise:@"AFFarmException"
                     format:@"Simulator did connect while not in Connecting state"];
        return;
    }

    [self log:@"Simulator created."];

    if(![simulator setBundlePath:modelPath])
    {
        [NSException raise:@"AFFarmException"
                     format:@"Unable to load model '%@'", modelPath];
        return;
    }
    
    [simulator setObserver:self];
    
    [self setFarmState: AFFarmEmptyState];
}
- (void)close:(id)sender
{
    if([self shouldClose])
    {
        [self performClose];
    }
}

- (BOOL)shouldClose
{
    int ret;
    
    ret = NSRunAlertPanel(@"Close farm",
                        @"Closing the farm will discard all collected data. Do you want to close the farm?",
                        @"Close", @"Cancel",nil);
    
    if(ret != NSAlertDefaultReturn)
    {
        return NO;
    }
    
    return YES;
}
- (void)performClose
{
    AFFarmController *controller;
    NSEnumerator     *enumerator;
    
    NSLog(@"-- CLOSING FARM");
    
    [self _postNotificationName:AFFarmWillCloseNotification];
    enumerator = [assistants objectEnumerator];

    while( (controller = [enumerator nextObject]) )
    {
        [controller close];
    }
    
    if(farmState == AFFarmRunningState)
    {
        NSLog(@"Stopping the simulator");
        [simulator stop];
    }

    [simulator destroySimulation];
    [simulator setObserver:nil];

    [[NSNotificationCenter defaultCenter]
                            removeObserver:self
                                      name:nil
                                    object:nil];

    [simulator terminate];
    DESTROY(simulator);
    DESTROY(farm);

    [self _postNotificationName:AFFarmDidCloseNotification];
    NSLog(@"-- DONE CLOSING");
}
/***************************************************************************
    Actions
****************************************************************************/
- (void)run:(id)sender
{
    switch(farmState)
    {
    case AFFarmDisconnectedState:
                [self connectToSimulator];
                break;
    case AFFarmEmptyState :
                [self launchSimulation];
                break;
    case AFFarmReadyState :
                isAnimating = NO;
                [self log:@"Run %i steps.", [self stepCount]];
                [simulator runSteps:[self stepCount]];
                break;

    case AFFarmRunningState:
                if(isAnimating == NO)
                {
                    [simulator stop];
                }
                else
                {
                    isAnimating = NO;
                }
                break;
    default:
                NSLog(@"Invalid state (%i) in Step", farmState);
    }

    [self setFarmState:farmState];
}
- (void) fastForward: (id)sender
{
    switch(farmState)
    {
    case AFFarmDisconnectedState:
                NSLog(@"Invalid state (disconnected) for Fast Forward");
                break;
    case AFFarmEmptyState :
                NSLog(@"Invalid state (empty) for Fast Forward");
                break;
    case AFFarmReadyState :
                isAnimating = YES;
                [self log:@"Fast forward. Watch each %i steps.", [self stepCount]];
                [simulator animateBySteps:[self stepCount]];
                break;

    case AFFarmRunningState:
                if(isAnimating == YES)
                {
                    isAnimating = NO;
                    [simulator stop];
                }
                break;
    default:
                NSLog(@"Invalid state (%i) in Step", farmState);
    }

    [self setFarmState:farmState];
}

- (void)restart:(id)sender
{
    int ret;

    ret = NSRunAlertPanel(@"Restart simulation",
                        @"Retarting the simulation will discard all collected data.",
                        @"Restart", @"Cancel",nil);

    if(ret == NSAlertDefaultReturn)
    {
        [self restartSimulation];
    }
}

- (void)stepCountChanged:(id)sender
{
    int stepCount = [sender intValue];
    
    if(stepCount < 1)
    {
        stepCount = 1;
    }

    [stepCountStepper setIntValue:stepCount];
    [stepCountStepper setNeedsDisplay:YES];

    [stepCountField setIntValue:stepCount];
    [stepCountField setNeedsDisplay:YES];
}

- (void)orderFrontFarmWindow:(id)sender
{
    /* FIXME: rename this method to orderForntMasterWindow: */
    [[self window] makeKeyAndOrderFront:nil];
}

- (void)debug:(id)sender
{
    [simulator debug];
}

- (id<AFLog>)log
{
    return farmLog;
}
/***************************************************************************
    Simulator and simulation
****************************************************************************/
- (void)launchSimulation
{
    NSString *reason = nil;
    [simulator setModel:[farm model]];

    NS_DURING
        [simulator createSimulation];
    NS_HANDLER
        if([[localException name] isEqual:NSUnknownKeyException])
        {
            reason = [NSString stringWithFormat:@"Unable to set value %@ for key %@",
                    [[localException userInfo] objectForKey:@"NSTargetObjectUserInfoKey"],
                    [[localException userInfo] objectForKey:@"NSUnknownUserInfoKey"]];
        }
        else
        {
            reason = [NSString stringWithFormat:@"%@ (%@:%@)", 
                                        [localException reason], 
                                        [localException name], 
                                        [localException userInfo]];
        }

        [self logError:@"Error during simulation launch. Reason: %@", reason];
        [simulator destroySimulation];
        return;
    NS_ENDHANDLER

    [self log:@"Simulation launched."];
    [self setFarmState:AFFarmReadyState];
    
    [self _postNotificationName:AFFarmDidLaunchNotification];
}

/** Restart the simulation. Destroy all simulation objects and clean collected 
    data. */
- (void)restartSimulation
{
    NSString *reason;
    
    /* We post this notification in advance, even if simulation
        is not destroyed properely. The reason is, that we can not assure
        that if it was not destroyed completely then it is ok. 
    */
    
    [self _postNotificationName:AFFarmDestroyedNotification];
    
    NS_DURING
        /*
        [self log:@"----------------"];
        [self log:@"BEFORE destroy:"];
        [self log:[simulator objectDebugDump]];
        */
        [simulator destroySimulation];
        /*
        [self log:@"----------------"];
        [self log:@"AFTER destroy:"];
        [self log:[simulator objectDebugDump]];
        */
    NS_HANDLER
        reason = [NSString stringWithFormat:@"%@ (%@:%@)", 
                                    [localException reason], 
                                    [localException name], 
                                    [localException userInfo]];

        [self logError:@"Error during destroyinh the simulation. Reason: %@", reason];
        return;
    NS_ENDHANDLER

    [self setFarmState:AFFarmEmptyState];
    [self log:@"Simulation destroyed."];
}

/** Change the sate of the farm. This method is used only by AFFarm object. */
- (void)setFarmState:(int)newState
{
    NSString *state = nil;
    NSString *title;

    // NSLog(@"Set farm state from %i to %i", farmState, newState);
    farmState = newState;
    
    switch(farmState)
    {
    case AFFarmDisconnectedState:
                [runButton setEnabled:YES];
                [runButton setImage:[NSImage imageNamed:@"Connect"]];

                [forwardButton setEnabled:NO];
                [restartButton setEnabled:NO];
                state = @"disconnected";
                break;
    case AFFarmConnectingState:
                [runButton setEnabled:NO];
                [forwardButton setEnabled:NO];
                [restartButton setEnabled:NO];
                state = @"connecting...";
                break;
    case AFFarmEmptyState:
                [runButton setEnabled:YES];
                [runButton setTitle:@"Launch"];
                [runButton setImage:[NSImage imageNamed:@"launch"]];

                [forwardButton setEnabled:NO];
                [forwardButton setImage:[NSImage imageNamed:@"runDisabled"]];

                [restartButton setEnabled:NO];
                [restartButton setImage:[NSImage imageNamed:@"restartDisabled"]];
                
                state = @"not launched";
                break;
    case AFFarmReadyState:
                [runButton setEnabled:YES];
                [runButton setTitle:@"Run"];
                [runButton setImage:[NSImage imageNamed:@"watch"]];

                [forwardButton setEnabled:YES];
                [forwardButton setTitle:@"Forward"];
                [forwardButton setImage:[NSImage imageNamed:@"run"]];

                [restartButton setEnabled:YES];
                [restartButton setImage:[NSImage imageNamed:@"restart"]];
                break;

    case AFFarmRunningState:
                if(isAnimating)
                {
                    [runButton setTitle:@"Run"];
                    [runButton setImage:[NSImage imageNamed:@"watch"]];

                    [forwardButton setTitle:@"Stop"];
                    [forwardButton setImage:[NSImage imageNamed:@"stop"]];

                    state = @"forwarding";
                }
                else
                {
                    [runButton setTitle:@"Stop"];
                    [runButton setImage:[NSImage imageNamed:@"stop"]];

                    [forwardButton setTitle:@"Forward"];
                    [forwardButton setImage:[NSImage imageNamed:@"run"]];

                    state = @"running";
                }

                [restartButton setEnabled:YES];
                [restartButton setImage:[NSImage imageNamed:@"restart"]];

                break;
    default:
                [NSException raise:@"AFFarmException"
                             format:@"Undefined farm state %i.", farmState];
    }
    
    if(state)
    {
        title = [NSString stringWithFormat:@"%@ (%@)", [[farm model] name], state];
    }
    else
    {
        title = [[farm model] name];
    }

    [[self window] setTitle:title];
    [self _postNotificationName:AFFarmStateChangedNotification];
}

- (int)farmState
{
    return farmState;
}

- (AFFarm *)farm
{
    return farm;
}

- (AFModel *)model
{
    return [farm model];
}

- (id <AFSimulator>)simulator
{
    return simulator;
}

/** Return YES if the farm is launched */
- (BOOL)isLaunched
{
    return farmState >= AFFarmReadyState; 
}
/***************************************************************************
    Simulator delegate
****************************************************************************/
- (oneway void) simulatorDidRun:(NSString *)tag time:(AFSimulationTime)time
{
    lastStepTime = [[NSDate alloc] init];

    [self setFarmState:AFFarmRunningState];
}
- (oneway void)simulatorDidFail:(NSString *)tag time:(AFSimulationTime)time
{
    NSException *exception = [simulator lastException];

    [self logError:@"Simulation did fail due to the exception: %@", 
                [exception reason]];
}

- (oneway void)simulatorDidStop:(NSString *)tag time:(AFSimulationTime)time
{
    if([simulator lastException] != nil)
    {
        [self simulatorDidFail:tag time:time];
    }

    [self log:@"Time elapsed: %f seconds.", 
            [[NSDate date] timeIntervalSinceDate:lastStepTime]];

    DESTROY(lastStepTime);
    [self setFarmState:AFFarmReadyState];
    [self _postNotificationName:AFFarmDidStopNotification];
    [timeField setIntValue:time];
    [timeField setNeedsDisplay:YES];
}

- (void)simulatorTimeAdvance:(NSString *)tag time:(AFSimulationTime)time
{
    //[self _postNotificationName:AFFarmTimeAdvancedNotification];
    NSLog(@"Time advance %i", time);
    [timeField setIntValue:time];
    [timeField setNeedsDisplay:YES];
}

- (int)stepCount
{
    return [stepCountField intValue];
}
- (oneway void) simulator:(NSString *)tag
       observedProperties:(bycopy NSDictionary *)dict
                     time:(AFSimulationTime)time
{
}
/* Forward a notification from simulator to the farm */
- (oneway void) simulatorNotification:(bycopy NSNotification *)notification
{
    NSNotification *notif;

    /* Make farm be the object and forward notification locally */
    /* FIXME: use some other mechanism */
    notif = [NSNotification notificationWithName:[notification name]
                                          object:self
                                        userInfo:[notification userInfo]];
    [[NSNotificationCenter defaultCenter] postNotification:notif];
}
/****************************************************************************
    Other
****************************************************************************/
- (BOOL)windowShouldClose:(NSWindow *)sender
{
    if(sender == [self window])
    {
        if([self shouldClose])
        {
            [self performClose];
            return YES;
        }
    }
    return NO;
}
#if 0
- (void)save:(id)sender
{
    NSSavePanel *savePanel;

    [self logWarning:@"Excuse me, but saving does not work yet. It is not fully implemented."];

    if(!storePath)
    {
        savePanel = [NSSavePanel savePanel];

        [savePanel setTitle:@"Save Farm"];
        [savePanel setRequiredFileType:@"afarm"];
        [savePanel setDirectory:[[FarmsController sharedController] storesDirectory]];

        if([savePanel runModal] == NSOKButton)
        {
            NSLog(@"Save to %@",[savePanel filename]);
            [[FarmsController sharedController] 
                                setStoresDirectory:[savePanel directory]];
        }
        storePath = [savePanel filename];
    }
    
    NSLog(@"Saving farm to %@.", storePath);
    
    [self saveInStoreAtPath:storePath];
    
    /* Save farm state */
    
}

- (void)saveAs:(id)sender
{
    [self logWarning:@"Save As... not implemented."];
}

- (void)saveInStoreAtPath:(NSString *)path
{
    AFFarmStore *store;
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    store = [AFFarmStore storeWithPath:path create:YES];

    /* Store the model */
    [store storeObject:self withName:@"model"];

    /* Store the farm information 
    
        Note: Some keys are not used on loading, they are written just for
              informational purposes.
    */
    
    [dict setObject:modelName forKey:@"ModelName"];
    [dict setObject:modelPath forKey:@"ModelPath"];
    [dict setObject:[NSNumber numberWithInt:farmState] forKey:@"FarmState"];
    [dict setObject:modelPath forKey:@"ModelPath"];
    [dict setObject:[farmWindow stringWithSavedFrame] forKey:@"FarmWindowFrame"];

    [dict setObject:[NSNumber numberWithInt:[self stepCount]]
             forKey:@"StepCount"];
              
    [store storePropertyList:dict withName:@"farm"];

    /* Store the simulation state */

    /*    
    state: archived simulation + time + environment
    [store storeObject:[simulator simulationState] withName:@"simulation"];
    */
    [store commit];
    NSLog(@"SAVE: done");
}

- initWithContentsOfFile:(NSString *)filename
{
    NSData *data;
    AFFarm *farm;
    
    data = [NSData dataWithContentsOfFile:filename];
    
    farm = [NSUnarchiver unarchiveObjectWithData:data];
    
    if(!farm)
    {
        [NSException raise:@"AFFarmException"
                     format:@"Unable to create farm from file %@", filename];
        [self dealloc];
        return nil;
    }
    
    RELEASE(data);
    RELEASE(farm);
    
    return AUTORELEASE(self);
}
#endif
@end
