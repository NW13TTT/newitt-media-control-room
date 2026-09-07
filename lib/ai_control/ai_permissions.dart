import '../auth/auth_models.dart';

enum AiPermissionLevel { assist, draft, publishWithApproval }

enum AiAction { explain, draftContent, publishContent, infrastructure }

class AiPermissionPolicy {
  const AiPermissionPolicy(this.session);

  final AuthSession? session;

  AiPermissionLevel get level {
    if (session == null) return AiPermissionLevel.assist;
    return switch (session!.profile.role) {
      AuthRole.masterAdmin => AiPermissionLevel.publishWithApproval,
      AuthRole.owner || AuthRole.customer => AiPermissionLevel.draft,
    };
  }

  bool allows(AiAction action, {String? websiteId}) {
    if (action == AiAction.infrastructure) return false;
    final currentSession = session;
    if (currentSession == null) return action == AiAction.explain;
    if (websiteId != null &&
        currentSession.profile.role != AuthRole.masterAdmin &&
        !currentSession.profile.websiteIds.contains(websiteId)) {
      return false;
    }
    return switch (action) {
      AiAction.explain => true,
      AiAction.draftContent => level != AiPermissionLevel.assist,
      AiAction.publishContent => level == AiPermissionLevel.publishWithApproval,
      AiAction.infrastructure => false,
    };
  }

  bool requiresHumanApproval(AiAction action) =>
      action == AiAction.publishContent && allows(action);

  String get label => switch (level) {
    AiPermissionLevel.assist => 'ASSIST',
    AiPermissionLevel.draft => 'DRAFT ONLY',
    AiPermissionLevel.publishWithApproval => 'PUBLISH WITH APPROVAL',
  };
}
