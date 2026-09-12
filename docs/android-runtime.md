# Android 原生执行层

AI 可先用 `inspectAndroidApi` 查询当前系统的公开构造器、方法和字段签名，再用 `executeAndroidScript` 组合调用。新增可通过公开 Android API 完成的操作，不必逐个增加业务工具。现有专用工具仍优先使用。

## 执行约定

- Rhino 1.7.15 解释模式，JavaScript ES6 子集，使用 `Packages` 调用 Java/Android 类。
- `app` 是 Application Context；`conversationId` 由当前运行会话注入，不由模型选择。
- 每次执行都需通过现有操作确认。使用 Aurai 的应用 UID 和已有系统权限；不提供 ADB、root 或绕过用户拒绝的能力。
- 独立 `:device_script` 进程运行，Application 不启动第二个 Flutter 引擎。一次只运行一个脚本，完成、取消、超时或连接失败后释放绑定，结束已知的执行进程。
- 10 秒执行上限包含进程启动时间；脚本最多 16000 字符，返回 JSON 最多 32768 字符。
- 每次都是新作用域，必须 `return` JSON 兼容的 JavaScript 值。Java 字符串用 `String(...)` 转换；不要返回 Context、Cursor 等原生对象。
- 代码在工作线程运行，没有 Activity、DOM、Node.js 或动态 JVM 字节码生成。JavaAdapter、自定义 Java 子类不可用。
- 后台线程、计时器和回调不应跨调用保存；需要持久任务时使用系统调度 API 和有效的 Android 组件。
- 超时和取消不撤销已经发生的副作用；重试前先观察状态。
- 独立进程用于故障和生命周期隔离，不是数据权限沙箱。脚本具备应用级数据访问能力，不能用来绕过通知脱敏、任务授权或系统保护。

## 查询和读取

`inspectAndroidApi` 参数示例：

```json
{"className":"android.os.BatteryManager","filter":"getIntProperty","offset":0}
```

`executeAndroidScript` 中的 `purpose` 使用用户语言说明具体访问与副作用，`script` 可为：

```javascript
var battery = app.getSystemService("batterymanager");
return { percent: battery.getIntProperty(4) };
```

## 直接调用原生通知 API

优先使用 `sendNotification`。下面示例说明原生执行层能够自行组合框架 API，不依赖新增业务分支：

```javascript
var manager = app.getSystemService("notification");
if (!manager.areNotificationsEnabled()) {
  return { sent: false, reason: "Notifications disabled" };
}
var channelId = "aurai_ai_notifications";
manager.createNotificationChannel(new Packages.android.app.NotificationChannel(
  channelId, "AI 通知", 3
));
if (manager.getNotificationChannel(channelId).getImportance() === 0) {
  return { sent: false, reason: "Channel disabled" };
}
var icon = app.getResources().getIdentifier(
  "ic_notification_aurai", "drawable", String(app.getPackageName())
);
var notification = new Packages.android.app.Notification$Builder(app, channelId)
  .setSmallIcon(icon).setContentTitle("Aurai").setContentText("任务提醒")
  .setAutoCancel(true).build();
manager.notify("device-script", 1, notification);
return { sent: true };
```

接口不存在或系统拒绝访问时，返回实际异常；不要把 API 签名存在等同于已获得执行权限。新增底层依赖和 Service 需要原生安装更新，Flutter 热更新不能启用它们。
