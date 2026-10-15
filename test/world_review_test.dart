import 'package:everlore/core/auth/auth_service.dart';
import 'package:everlore/features/billing/data/billing_repository.dart';
import 'package:everlore/features/billing/presentation/billing_screen.dart';
import 'package:everlore/features/creator/data/meaningful_edit_detector.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/creator/presentation/widgets/world_status_chip.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldTemplate review fields parsing', () {
    test('parses new review fields when present', () {
      final template = WorldTemplate.fromJson({
        'id': 't1',
        'title': 'The Ashen Vale',
        'description': 'A grim valley.',
        'is_published': true,
        'visibility': 'public',
        'review_status': 'changes_requested',
        'review_note': 'Needs a softer opening line.',
      });

      expect(template.visibility, 'public');
      expect(template.reviewStatus, 'changes_requested');
      expect(template.reviewNote, 'Needs a softer opening line.');
      expect(template.reviewState, WorldReviewState.changesRequested);
      expect(template.reviewStateLabel, 'Needs changes');
    });

    test('parses legacy published world without visibility as public + approved', () {
      final template = WorldTemplate.fromJson({
        'id': 't2',
        'title': 'Legacy Kingdom',
        'description': 'An ancient realm.',
        'is_published': true,
      });

      expect(template.visibility, isNull);
      expect(template.reviewStatus, isNull);
      expect(template.reviewNote, isNull);
      expect(template.reviewState, WorldReviewState.approved);
      expect(template.reviewStateLabel, 'Shared with all');
    });

    test('parses unpublished draft correctly', () {
      final template = WorldTemplate.fromJson({
        'id': 't3',
        'title': 'Rough Sketch',
        'description': 'Work in progress.',
        'is_published': false,
      });

      expect(template.reviewState, WorldReviewState.unpublished);
      expect(template.reviewStateLabel, 'Draft');
    });

    test('parses private world correctly', () {
      final template = WorldTemplate.fromJson({
        'id': 't4',
        'title': 'Secret Garden',
        'description': 'Personal sanctuary.',
        'is_published': true,
        'visibility': 'private',
      });

      expect(template.reviewState, WorldReviewState.private);
      expect(template.reviewStateLabel, 'Just for you');
    });

    test('parses pending public world correctly', () {
      final template = WorldTemplate.fromJson({
        'id': 't5',
        'title': 'New Voyage',
        'description': 'Waiting for review.',
        'is_published': true,
        'visibility': 'public',
        'review_status': 'pending',
      });

      expect(template.reviewState, WorldReviewState.pending);
      expect(template.reviewStateLabel, 'Awaiting the seal');
    });

    test('parses approved public world correctly', () {
      final template = WorldTemplate.fromJson({
        'id': 't6',
        'title': 'The Great Hall',
        'description': 'Approved public world.',
        'is_published': true,
        'visibility': 'public',
        'review_status': 'approved',
      });

      expect(template.reviewState, WorldReviewState.approved);
      expect(template.reviewStateLabel, 'Shared with all');
    });
  });

  group('User can_forge parsing and AuthService fallback', () {
    test('parses can_forge true and false from json', () {
      final userTrue = User.fromJson({
        'id': 'u1',
        'email': 'a@b.com',
        'tier': 'free',
        'can_forge': true,
      });
      expect(userTrue.canForge, isTrue);
      expect(userTrue.canAccessForge, isTrue);

      final userFalse = User.fromJson({
        'id': 'u2',
        'email': 'b@c.com',
        'tier': 'premium',
        'can_forge': false,
      });
      expect(userFalse.canForge, isFalse);
      expect(userFalse.canAccessForge, isFalse);
    });

    test('falls back to tier when can_forge is omitted/null', () {
      final freeUser = User.fromJson({
        'id': 'u3',
        'email': 'c@d.com',
        'tier': 'free',
      });
      expect(freeUser.canForge, isNull);
      expect(freeUser.canAccessForge, isFalse);
      expect(AuthService.canAccessForge(freeUser), isFalse);

      final premiumUser = User.fromJson({
        'id': 'u4',
        'email': 'd@e.com',
        'tier': 'premium',
      });
      expect(premiumUser.canForge, isNull);
      expect(premiumUser.canAccessForge, isTrue);
      expect(AuthService.canAccessForge(premiumUser), isTrue);

      final creatorUser = User.fromJson({
        'id': 'u5',
        'email': 'e@f.com',
        'tier': 'creator',
      });
      expect(creatorUser.canForge, isNull);
      expect(creatorUser.canAccessForge, isTrue);
      expect(AuthService.canAccessForge(creatorUser), isTrue);

      expect(AuthService.canAccessForge(null), isFalse);
    });
  });

  group('WorldStatusChip widget tests', () {
    testWidgets('renders all five state labels', (tester) async {
      final templates = [
        WorldTemplate.fromJson({'id': '1', 'title': 'A', 'is_published': false}),
        WorldTemplate.fromJson({'id': '2', 'title': 'B', 'is_published': true, 'visibility': 'private'}),
        WorldTemplate.fromJson({'id': '3', 'title': 'C', 'is_published': true, 'visibility': 'public', 'review_status': 'pending'}),
        WorldTemplate.fromJson({'id': '4', 'title': 'D', 'is_published': true, 'visibility': 'public', 'review_status': 'approved'}),
        WorldTemplate.fromJson({'id': '5', 'title': 'E', 'is_published': true, 'visibility': 'public', 'review_status': 'changes_requested', 'review_note': 'Fix this'}),
      ];

      final expectedLabels = [
        'Draft',
        'Just for you',
        'Awaiting the seal',
        'Shared with all',
        'Needs changes',
      ];

      for (var i = 0; i < templates.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorldStatusChip(template: templates[i]),
            ),
          ),
        );
        expect(find.text(expectedLabels[i]), findsOneWidget);
      }
    });

    testWidgets('renders review note in quotes when changesRequested', (tester) async {
      final template = WorldTemplate.fromJson({
        'id': 'req',
        'title': 'Test World',
        'is_published': true,
        'visibility': 'public',
        'review_status': 'changes_requested',
        'review_note': 'Please adjust character backstory.',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldStatusChip(template: template),
          ),
        ),
      );

      expect(find.text('Needs changes'), findsOneWidget);
      expect(find.text('"Please adjust character backstory."'), findsOneWidget);
    });

    testWidgets('does not render note when state is not changesRequested', (tester) async {
      final template = WorldTemplate.fromJson({
        'id': 'appr',
        'title': 'Test World',
        'is_published': true,
        'visibility': 'public',
        'review_status': 'approved',
        'review_note': 'Old note that should not show.',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldStatusChip(template: template),
          ),
        ),
      );

      expect(find.text('Shared with all'), findsOneWidget);
      expect(find.text('"Old note that should not show."'), findsNothing);
    });
  });

  group('MeaningfulEditDetector', () {
    final baseWorld = WorldTemplate.fromJson({
      'id': 'w1',
      'title': 'Original Title',
      'description': 'Original Description',
      'image_url': 'https://example.com/art.png',
      'seed_prompt': 'Prompt A',
      'global_lore': 'Lore A',
      'opening_line': 'Opening A',
      'kind': 'fantasy',
      'is_sentient': true,
      'is_nsfw_capable': false,
      'protagonist': {'name': 'Hero'},
      'seed_cast': [{'name': 'Companion'}],
      'stats': [{'name': 'Strength', 'initial_value': 10}],
      'is_published': true,
      'visibility': 'public',
      'review_status': 'approved',
    });

    test('detects meaningful field changes on template', () {
      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {'title': 'New Title'},
        ),
        isTrue,
      );

      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {'description': 'New Description'},
        ),
        isTrue,
      );

      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {'seed_prompt': 'Changed prompt'},
        ),
        isTrue,
      );

      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {'is_sentient': false},
        ),
        isTrue,
      );

      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {'seed_cast': [{'name': 'New Companion'}]},
        ),
        isTrue,
      );
    });

    test('returns false when only non-meaningful fields (stats/flags) change', () {
      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {
            'stats': [{'name': 'Strength', 'initial_value': 20}],
            'flags': ['flag_a'],
          },
        ),
        isFalse,
      );

      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          baseWorld,
          {},
        ),
        isFalse,
      );

      // The forge trims before saving; trailing whitespace is not an edit.
      expect(
        MeaningfulEditDetector.hasMeaningfulChanges(
          WorldTemplate.fromJson({'id': 'w2', 'title': 'Spaced Title '}),
          {'title': 'Spaced Title'},
        ),
        isFalse,
      );
    });
  });

  group('PublishWorldSheet widget tests', () {
    final template = WorldTemplate.fromJson({
      'id': 'sheet_test',
      'title': 'My Story',
      'is_published': false,
    });

    testWidgets('defaults to private ("Just for you")', (tester) async {
      String? publishedVisibility;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublishWorldSheet(
              template: template,
              onPublish: (v) async {
                publishedVisibility = v;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Who can enter this world?'), findsOneWidget);
      expect(find.text('You can change this later.'), findsOneWidget);
      expect(find.text('Just for you'), findsOneWidget);
      expect(find.text('For every traveller'), findsOneWidget);

      await tester.tap(find.text('Publish'));
      await tester.pump();

      expect(publishedVisibility, 'private');
    });

    testWidgets('allows selecting public ("For every traveller")', (tester) async {
      String? publishedVisibility;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublishWorldSheet(
              template: template,
              onPublish: (v) async {
                publishedVisibility = v;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('For every traveller'));
      await tester.pump();

      await tester.tap(find.text('Publish'));
      await tester.pump();

      expect(publishedVisibility, 'public');
    });

    testWidgets('respects initialVisibility parameter', (tester) async {
      String? publishedVisibility;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublishWorldSheet(
              template: template,
              initialVisibility: 'public',
              onPublish: (v) async {
                publishedVisibility = v;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Publish'));
      await tester.pump();

      expect(publishedVisibility, 'public');
    });
  });

  group('Promo Membership BillingScreen widget tests', () {
    const promoWallet = BillingWallet(
      tier: 'free',
      balance: 0,
      monthlyInk: 0,
      dailyStorySafetyCap: 40,
      purchasesEnabled: false,
      simulationEnabled: false,
      unlimitedInk: true,
    );

    testWidgets('shows all three rows when canForge is true', (tester) async {
      tester.view.physicalSize = const Size(1280, 2856);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final userWithForge = User.fromJson({
        'id': 'u_forge',
        'email': 'forge@example.com',
        'tier': 'free',
        'can_forge': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BillingScreen(
            wallet: promoWallet,
            user: userWithForge,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WHILE THE INK FLOWS FREE'), findsOneWidget);
      expect(find.text('Every story, without counting'), findsOneWidget);
      expect(find.text('Write as many turns as you like.'), findsOneWidget);
      expect(find.text('Forge your own worlds'), findsOneWidget);
      expect(
        find.text('Make worlds and characters, whatever your membership.'),
        findsOneWidget,
      );
      expect(find.text('Portraits and drafts, free'), findsOneWidget);
      expect(find.text('Cover art and story drafts cost no ink.'), findsOneWidget);
      expect(
        find.text(
          'Memberships return when the promotion ends. Everything you write now stays yours.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('omits "Forge your own worlds" row when canForge is false', (tester) async {
      tester.view.physicalSize = const Size(1280, 2856);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final userWithoutForge = User.fromJson({
        'id': 'u_no_forge',
        'email': 'noforge@example.com',
        'tier': 'free',
        'can_forge': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BillingScreen(
            wallet: promoWallet,
            user: userWithoutForge,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WHILE THE INK FLOWS FREE'), findsOneWidget);
      expect(find.text('Every story, without counting'), findsOneWidget);
      expect(find.text('Portraits and drafts, free'), findsOneWidget);
      expect(find.text('Forge your own worlds'), findsNothing);
      expect(
        find.text('Make worlds and characters, whatever your membership.'),
        findsNothing,
      );
    });
  });
}
