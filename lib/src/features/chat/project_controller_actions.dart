part of 'chat_controller.dart';

extension ProjectControllerActions on ChatController {
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
    String instructions = '',
    List<ProjectDirectory> directories = const [],
    List<String> directoryNames = const [],
  }) async {
    validateProjectName(name);
    final id = newMessageId();
    final createdDirectories = <ProjectDirectory>[];
    for (final directoryName
        in directoryNames.isEmpty ? [name] : directoryNames) {
      final output = await _platform.deviceExtension('createManagedProject', {
        'id': newMessageId(),
        'name': directoryName,
      });
      createdDirectories.add(
        ProjectDirectory(uri: output['uri'] as String, name: directoryName),
      );
    }
    final now = DateTime.now();
    final project = DevelopmentProject(
      id: id,
      name: name,
      description: description,
      instructions: instructions,
      icon: icon,
      iconColor: iconColor,
      directories: [...createdDirectories, ...directories],
      createdAt: now,
      updatedAt: now,
    );
    await projects.create(project);
    notifyListeners();
    return project;
  }

  Future<DevelopmentProject> createExternalProject(
    String name,
    String icon,
    String iconColor,
    List<ProjectDirectory> directories, {
    String description = '',
    String instructions = '',
  }) async {
    validateProjectName(name);
    final now = DateTime.now();
    final project = DevelopmentProject(
      id: newMessageId(),
      name: name,
      description: description,
      instructions: instructions,
      icon: icon,
      iconColor: iconColor,
      directories: directories,
      createdAt: now,
      updatedAt: now,
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
    required String instructions,
    required String icon,
    required String iconColor,
  }) async {
    validateProjectName(name);
    await projects.updateProfile(
      project.id,
      name: name,
      description: description,
      instructions: instructions,
      icon: icon,
      iconColor: iconColor,
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
