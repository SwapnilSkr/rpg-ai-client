import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/widgets/member_avatar.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupChatRow.parse', () {
    Map<String, dynamic> row({Object? imageThumb, Object? portraitThumb}) => {
      'instance_id': 'i1',
      'template_id': 't1',
      'title': 'G',
      'image_url': 'https://cdn/full.png',
      'image_thumb_url': ?imageThumb,
      'members': [
        {
          'id': 'a',
          'name': 'Ana',
          'portrait_url': 'https://cdn/ana.png',
          'portrait_thumb_url': ?portraitThumb,
        },
      ],
    };

    test('reads both small urls', () {
      final r = GroupChatRow.parse(
        row(
          imageThumb: 'https://cdn/t.png',
          portraitThumb: 'https://cdn/at.png',
        ),
      )!;
      expect(r.imageUrl, 'https://cdn/full.png');
      expect(r.imageThumbUrl, 'https://cdn/t.png');
      expect(r.members.single.portraitUrl, 'https://cdn/ana.png');
      expect(r.members.single.portraitThumbUrl, 'https://cdn/at.png');
    });

    test('missing, null and empty mean none', () {
      for (final r in [
        GroupChatRow.parse(row())!,
        GroupChatRow.parse(row(imageThumb: null, portraitThumb: null))!,
        GroupChatRow.parse(row(imageThumb: '', portraitThumb: ''))!,
      ]) {
        expect(r.imageThumbUrl, isNull);
        expect(r.members.single.portraitThumbUrl, isNull);
        expect(r.imageUrl, 'https://cdn/full.png');
      }
    });

    test('the small url takes part in equality', () {
      expect(
        GroupChatRow.parse(row(imageThumb: 'a')),
        isNot(GroupChatRow.parse(row(imageThumb: 'b'))),
      );
      expect(
        const GroupMember(id: 'a', name: 'A', portraitThumbUrl: 'x'),
        isNot(const GroupMember(id: 'a', name: 'A', portraitThumbUrl: 'y')),
      );
    });
  });

  group('GroupSnapshot.parse', () {
    GroupSnapshot? snap(Map<String, dynamic> card) => GroupSnapshot.parse({
      'data': {
        'instance': {'id': 'i1'},
        'characters': [card],
      },
    });

    Map<String, dynamic> card({Object? thumb, bool withKey = true}) => {
      'id': 'a',
      'canonical_name': 'Ana',
      'portrait_url': 'https://cdn/ana.png',
      if (withKey) 'portrait_thumb_url': thumb,
    };

    test('room member card keeps full and small apart', () {
      final m = snap(card(thumb: 'https://cdn/at.png'))!.members.single;
      expect(m.portraitUrl, 'https://cdn/ana.png');
      expect(m.portraitThumbUrl, 'https://cdn/at.png');
    });

    test('absent, null and empty mean none', () {
      for (final c in [
        card(withKey: false),
        card(thumb: null),
        card(thumb: ''),
      ]) {
        expect(snap(c)!.members.single.portraitThumbUrl, isNull);
      }
    });
  });

  group('WorldTemplate / TemplateMember', () {
    Map<String, dynamic> template({Object? thumb, bool withKey = true}) => {
      'id': 't1',
      'title': 'T',
      'image_url': 'https://cdn/full.png',
      if (withKey) 'image_thumb_url': thumb,
      'members': [
        {
          'name': 'Ana',
          'portrait_url': 'https://cdn/ana.png',
          if (withKey) 'portrait_thumb_url': thumb,
        },
      ],
    };

    test('reads small urls', () {
      final t = WorldTemplate.fromJson(template(thumb: 'https://cdn/t.png'));
      expect(t.imageUrl, 'https://cdn/full.png');
      expect(t.imageThumbUrl, 'https://cdn/t.png');
      expect(t.members.single.portraitThumbUrl, 'https://cdn/t.png');
      expect(t.copyWith(title: 'x').imageThumbUrl, 'https://cdn/t.png');
    });

    test('absent, null and empty mean none', () {
      for (final j in [
        template(withKey: false),
        template(thumb: null),
        template(thumb: ''),
      ]) {
        final t = WorldTemplate.fromJson(j);
        expect(t.imageThumbUrl, '');
        expect(t.members.single.portraitThumbUrl, isNull);
        expect(t.imageUrl, 'https://cdn/full.png');
      }
    });
  });

  // CachedNetworkImage needs platform plugins a unit test lacks, so the
  // failure branch is tested directly and the avatar's choice by its props.
  group('EverloreNetworkImage fallbackUrl', () {
    test('a failing small url yields the full image, which has no retry', () {
      const image = EverloreNetworkImage(
        imageUrl: 'https://cdn/small.png',
        fallbackUrl: 'https://cdn/full.png',
        memCacheWidth: 720,
        errorWidget: Text('gave up'),
      );
      final next = image.buildFailure() as EverloreNetworkImage;
      expect(next.imageUrl, 'https://cdn/full.png');
      expect(next.fallbackUrl, isNull);
      expect(next.memCacheWidth, 720);
      expect(next.errorWidget, isA<Text>());
      // The full image failing too ends in the error widget.
      expect(next.buildFailure(), isA<Text>());
    });

    test(
      'no, empty or identical fallback goes straight to the error widget',
      () {
        for (final f in [null, '', 'https://cdn/small.png']) {
          final image = EverloreNetworkImage(
            imageUrl: 'https://cdn/small.png',
            fallbackUrl: f,
            errorWidget: const Text('gave up'),
          );
          expect(image.buildFailure(), isA<Text>());
        }
      },
    );

    testWidgets('MemberAvatar asks for the small url, full as fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MemberAvatar(
            member: GroupMember(
              id: 'a',
              name: 'Ana',
              portraitUrl: 'https://cdn/full.png',
              portraitThumbUrl: 'https://cdn/thumb.png',
            ),
          ),
        ),
      );
      final image = tester.widget<EverloreNetworkImage>(
        find.byType(EverloreNetworkImage),
      );
      expect(image.imageUrl, 'https://cdn/thumb.png');
      expect(image.fallbackUrl, 'https://cdn/full.png');
    });

    testWidgets('MemberAvatar without a small url uses the full one', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MemberAvatar(name: 'Ana', portraitUrl: 'https://cdn/full.png'),
        ),
      );
      final image = tester.widget<EverloreNetworkImage>(
        find.byType(EverloreNetworkImage),
      );
      expect(image.imageUrl, 'https://cdn/full.png');
      expect(image.fallbackUrl, 'https://cdn/full.png');
    });
  });
}
