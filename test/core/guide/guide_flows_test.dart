import 'package:everlore/core/guide/guide_flows.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group chat guide flows', () {
    test('every new flow is in all in order after chats', () {
      final chatsIndex = GuideFlows.all.indexOf(GuideFlows.chats);
      expect(chatsIndex, isNonNegative);

      final expectedOrder = [
        GuideFlows.chats,
        GuideFlows.navChats,
        GuideFlows.groupPreview,
        GuideFlows.groupRoom,
        GuideFlows.groupIdeas,
        GuideFlows.groupHold,
        GuideFlows.groupDirect,
        GuideFlows.groupActions,
        GuideFlows.notifications,
      ];

      for (var i = 0; i < expectedOrder.length; i++) {
        expect(GuideFlows.all[chatsIndex + i], equals(expectedOrder[i]));
      }
    });

    test('all flow ids in GuideFlows.all are unique', () {
      final ids = GuideFlows.all.map((f) => f.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('new flows have unique declared ids', () {
      expect(GuideFlows.navChats.id, 'nav.chats');
      expect(GuideFlows.groupPreview.id, 'group.preview');
      expect(GuideFlows.groupRoom.id, 'group.room');
      expect(GuideFlows.groupIdeas.id, 'group.ideas');
      expect(GuideFlows.groupHold.id, 'group.hold');
      expect(GuideFlows.groupDirect.id, 'group.direct');
      expect(GuideFlows.groupActions.id, 'group.actions');
      expect(GuideFlows.notifications.id, 'notifications');
    });

    test('each new flow has the exact words and anchors from the brief', () {
      // 1. nav.chats
      final navChats = GuideFlows.navChats;
      expect(navChats.route, '/');
      expect(navChats.beats, hasLength(1));
      expect(navChats.beats[0].anchor, GuideIds.navChats);
      expect(navChats.beats[0].title, 'Rooms That Talk Back');
      expect(
        navChats.beats[0].body,
        'Beyond your worlds are rooms full of people who talk among themselves, and to you.',
      );

      // 2. group.preview
      final preview = GuideFlows.groupPreview;
      expect(preview.route, '/group-preview');
      expect(preview.beats, hasLength(1));
      expect(preview.beats[0].anchor, GuideIds.groupPreviewFaces);
      expect(preview.beats[0].title, "Who You'll Find");
      expect(
        preview.beats[0].body,
        'Each has their own temper and their own reasons to speak. Not all of them will answer at once.',
      );

      // 3. group.room (two beats)
      final room = GuideFlows.groupRoom;
      expect(room.route, '/group');
      expect(room.beats, hasLength(2));
      expect(room.beats[0].anchor, GuideIds.groupRoomComposer);
      expect(room.beats[0].title, 'Speak to the Room');
      expect(
        room.beats[0].body,
        'Say something and someone will answer. Name one of them with @ and that one will.',
      );
      expect(room.beats[1].anchor, GuideIds.groupRoomFaces);
      expect(room.beats[1].title, 'Faces at the Table');
      expect(
        room.beats[1].body,
        'Open any face to see how they feel about you, or to speak with them alone.',
      );

      // 4. group.ideas
      final ideas = GuideFlows.groupIdeas;
      expect(ideas.beats, hasLength(1));
      expect(ideas.beats[0].anchor, GuideIds.groupIdeas);
      expect(ideas.beats[0].title, 'A Word Ready');
      expect(
        ideas.beats[0].body,
        'When nothing comes to mind, a few openings wait above your line.',
      );

      // 5. group.hold
      final hold = GuideFlows.groupHold;
      expect(hold.route, '/group');
      expect(hold.beats, hasLength(1));
      expect(hold.beats[0].anchor, GuideIds.groupHoldLine);
      expect(hold.beats[0].fallbackAnchor, GuideIds.groupHoldList);
      expect(hold.beats[0].title, 'Keeping the Moment');
      expect(
        hold.beats[0].body,
        'Hold any line to keep its words, report it, or return the room to that moment.',
      );

      // 6. group.direct
      final direct = GuideFlows.groupDirect;
      expect(direct.beats, hasLength(1));
      expect(direct.beats[0].anchor, GuideIds.groupDirectHeader);
      expect(direct.beats[0].title, 'Between the Two of You');
      expect(
        direct.beats[0].body,
        "What is said here stays here. The others won't hear it.",
      );

      // 7. group.actions
      final actions = GuideFlows.groupActions;
      expect(actions.route, '/group');
      expect(actions.beats, hasLength(1));
      expect(actions.beats[0].anchor, GuideIds.groupFirstAction);
      expect(actions.beats[0].requiresAnchor, isTrue);
      expect(actions.beats[0].title, 'Doing, Not Saying');
      expect(
        actions.beats[0].body,
        'Some moments ask for something done rather than said.',
      );

      // 8. notifications
      final notifs = GuideFlows.notifications;
      expect(notifs.beats, hasLength(1));
      expect(notifs.beats[0].anchor, GuideIds.notificationsBell);
      expect(notifs.beats[0].title, 'Word From Elsewhere');
      expect(
        notifs.beats[0].body,
        'When someone writes while you are away, it waits here.',
      );
    });

    test('no new beat contains banned interface words', () {
      final banned = RegExp(
        r'\b(tap|taps|tapping|button|screen|click|ai)\b',
        caseSensitive: false,
      );
      final newFlows = [
        GuideFlows.navChats,
        GuideFlows.groupPreview,
        GuideFlows.groupRoom,
        GuideFlows.groupIdeas,
        GuideFlows.groupHold,
        GuideFlows.groupDirect,
        GuideFlows.groupActions,
        GuideFlows.notifications,
      ];
      for (final flow in newFlows) {
        for (final beat in flow.beats) {
          expect(
            banned.hasMatch('${beat.title} ${beat.body}'),
            isFalse,
            reason: '${flow.id}: "${beat.title} - ${beat.body}"',
          );
        }
      }
    });
  });
}
