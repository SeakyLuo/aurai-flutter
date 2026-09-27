part of 'chat_controller.dart';

extension ProjectControllerActions on ChatController {
  Future<void> selectConversationWorkspace(
    String conversationId,
    DevelopmentProject project,
  ) async {
    if ({_execution, ..._executionStates.values}.any(
      (state) =>
          state.conversation?.id == conversationId &&
          (state.runningConversation != null ||
              state.privateConversation != null ||
              state.submitting),
    )) {
      throw StateError('请等待当前任务完成或停止后再切换工作目录');
    }
    await projects.bindWorktree(conversationId, project);
    _conversationChanged();
  }

  Future<void> createProjectConversation(
    DevelopmentProject project, {
    required String senderId,
  }) async {
    await createConversation();
    activeConversation.projectId = project.id;
    activeConversation.storedTitle = null;
    activeConversation.defaultSenderId = senderId;
    _activeAi = await groupStore.loadAi(senderId);
    await _newDraftStore.save(activeConversation);
    await projects.bindWorktree(activeConversation.id, project);
    _conversationChanged();
  }

  Future<void> setActiveDraftSender(String senderId) async {
    activeConversation.defaultSenderId = senderId;
    _activeAi = await groupStore.loadAi(senderId);
    await _persist();
    _conversationChanged();
  }

  DevelopmentProjects get projects => DevelopmentProjects(_store.database);

  Future<DevelopmentProject> createManagedProject(
    String name,
    String icon,
    String iconColor, {
    String description = '',
    String gitRemoteUrl = '',
  }) async {
    validateProjectName(name);
    final id = newMessageId();
    final output = await _platform.deviceExtension('createManagedProject', {
      'id': id,
      'name': name,
    });
    if (gitRemoteUrl.isNotEmpty) {
      await _platform.deviceExtension('projectDevelopmentOperation', {
        'projectId': id,
        'operation': 'initializeProjectGit',
        'arguments': <String, Object?>{},
      });
      await _platform.deviceExtension('projectDevelopmentOperation', {
        'projectId': id,
        'operation': 'setProjectGitRemote',
        'arguments': {'url': gitRemoteUrl},
      });
    }
    final now = DateTime.now();
    final project = DevelopmentProject(
      id: id,
      name: name,
      description: description,
      icon: icon,
      iconColor: iconColor,
      rootUri: output['uri'] as String,
      location: ProjectLocation.managed,
      createdAt: now,
      updatedAt: now,
      gitRemoteUrl: gitRemoteUrl,
    );
    await projects.create(project);
    notifyListeners();
    return project;
  }

  Future<DevelopmentProject> createExternalProject(
    String name,
    String icon,
    String iconColor,
    String rootUri, {
    String description = '',
    String gitRemoteUrl = '',
  }) async {
    validateProjectName(name);
    final now = DateTime.now();
    final project = DevelopmentProject(
      id: newMessageId(),
      name: name,
      description: description,
      icon: icon,
      iconColor: iconColor,
      rootUri: rootUri,
      location: ProjectLocation.external,
      createdAt: now,
      updatedAt: now,
      gitRemoteUrl: gitRemoteUrl,
    );
    await projects.create(project);
    notifyListeners();
    return project;
  }

  Future<void> setConversationProject(
    Conversation conversation,
    String? projectId, {
    String actorId = 'user:local',
  }) async {
    await projects.assignConversation(
      conversation.id,
      projectId,
      actorId: actorId,
    );
    conversation.projectId = projectId;
    if (activeConversation.id == conversation.id) {
      activeConversation.projectId = projectId;
    }
    notifyListeners();
  }

  Future<DevelopmentProject> updateProjectProfile(
    DevelopmentProject project, {
    required String name,
    required String description,
    required String icon,
    required String iconColor,
    required String gitRemoteUrl,
  }) async {
    validateProjectName(name);
    if (project.location == ProjectLocation.managed &&
        project.gitRemoteUrl != gitRemoteUrl) {
      await _platform.deviceExtension('projectDevelopmentOperation', {
        'projectId': project.id,
        'operation': 'initializeProjectGit',
        'arguments': <String, Object?>{},
      });
      await _platform.deviceExtension('projectDevelopmentOperation', {
        'projectId': project.id,
        'operation': 'setProjectGitRemote',
        'arguments': {'url': gitRemoteUrl},
      });
    }
    await projects.updateProfile(
      project.id,
      name: name,
      description: description,
      icon: icon,
      iconColor: iconColor,
      gitRemoteUrl: gitRemoteUrl,
    );
    notifyListeners();
    return projects.read(project.id);
  }

  Future<DevelopmentProject> setProjectPinned(
    DevelopmentProject project,
    bool pinned,
  ) async {
    await projects.setPinned(project.id, pinned);
    notifyListeners();
    return projects.read(project.id);
  }

  Future<DevelopmentProject> setProjectMemoryMode(
    DevelopmentProject project,
    ProjectMemoryMode mode,
  ) async {
    await projects.setMemoryMode(project.id, mode);
    notifyListeners();
    return projects.read(project.id);
  }

  Future<DevelopmentProject> setProjectInstructions(
    DevelopmentProject project,
    String instructions,
  ) async {
    await projects.setInstructions(project.id, instructions.trim());
    notifyListeners();
    return projects.read(project.id);
  }

  Future<DevelopmentProject> setProjectDefaultSender(
    DevelopmentProject project,
    String senderId,
  ) async {
    await projects.setDefaultSender(project.id, senderId);
    notifyListeners();
    return projects.read(project.id);
  }

  Future<void> removeProject(DevelopmentProject project) async {
    requireProjectIdle(project.id);
    if (project.location == ProjectLocation.managed) {
      await _platform.deviceExtension('removeManagedProject', {
        'id': project.id,
      });
    }
    await projects.remove(project.id);
    await _reloadConversations();
    notifyListeners();
  }

  Future<void> markProjectRead(DevelopmentProject project) async {
    await projects.markAllRead(project.id);
    await _reloadConversations();
    notifyListeners();
  }
}
