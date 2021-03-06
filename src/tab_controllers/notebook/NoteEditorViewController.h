//
//  NoteEditorViewController.h
//  ARIS
//
//  Created by Phil Dougherty on 11/6/13.
//
//

#import "ARISViewController.h"

@class Note;
@class NoteEditorViewController;

@protocol NoteEditorViewControllerDelegate
- (void) noteEditorCancelledNoteEdit:(NoteEditorViewController *)ne;
- (void) noteEditorConfirmedNoteEdit:(NoteEditorViewController *)ne note:(Note *)n;
- (void) noteEditorDeletedNoteEdit:(NoteEditorViewController *)ne;
@end

typedef enum
{
    NOTE_EDITOR_MODE_TEXT,
    NOTE_EDITOR_MODE_AUDIO,
    NOTE_EDITOR_MODE_CAMERA,
    NOTE_EDITOR_MODE_ROLL,
    NOTE_EDITOR_MODE_NONE
} NoteEditorMode;

@interface NoteEditorViewController : ARISViewController
- (id) initWithNote:(Note *)n mode:(NoteEditorMode)m delegate:(id<NoteEditorViewControllerDelegate>)d;
@end
