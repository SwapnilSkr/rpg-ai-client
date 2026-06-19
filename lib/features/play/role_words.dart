/// Premise-backed role labels that name a real (if un-carded) person the player
/// relates TO — the family/titled NPCs the narration introduces by role before
/// they have a proper-name codex card.
///
/// This is the SINGLE source of truth for the client. It mirrors:
/// - backend `trackableFamilyLabels` (worker/processors/generation.processor.ts)
/// - audit `FAMILY_ROLE_WORDS` (scripts/presence-codex-gap-audit.ts)
///
/// Keep all three in sync: adding a role here means adding it backend-side and
/// audit-side too. Child/self-facing labels ("son", "daughter", "child") are
/// deliberately excluded so the player is never flagged as a missed "Son".
const Set<String> familyRoleWords = {
  'father',
  'mother',
  'mom',
  'dad',
  'parent',
  'parents',
  'sister',
  'brother',
  'sibling',
  'twin sister',
  'twin brother',
  'twin',
  'wife',
  'husband',
  'spouse',
  'partner',
  'fiancee',
  'fiance',
  'girlfriend',
  'boyfriend',
  'cousin',
  'aunt',
  'uncle',
  'grandmother',
  'grandfather',
  'grandma',
  'grandpa',
  'butler',
  'captain',
  'king',
  'queen',
  'prince',
  'princess',
  'lord',
  'lady',
};
