import 'package:websocket_universal/websocket_universal.dart';

/// Example for websocket article `Part One`
void main() async {
  /// Postman echo ws server (you can use your own server URI)
  /// For local server it could look like 'ws://127.0.0.1:42627/websocket'
  const websocketConnectionUri = 'wss://ws.postman-echo.com/raw';
  const textMessageToServer = 'Hello server!';
  const connectionOptions = SocketConnectionOptions(
    pingIntervalMs: 1000, // send Ping message every 3000 ms
    timeoutConnectionMs: 4000, // connection fail timeout after 4000 ms
    /// see ping/pong messages in
    /// [incomingMessagesStream] and [outgoingMessagesStream] streams
    skipPingMessages: false,
  );

  /// Example with simple text messages exchanges with server
  /// (not recommended for applications)
  /// [<String, String>] generic types mean that we receive [String] messages
  /// after deserialization and send [String] messages to server.
  final IMessageProcessor<String, String> textSocketProcessor =
      SocketSimpleTextProcessor();

  /// Creating webSocket handler object:
  final textSocketHandler = IWebSocketHandler<String, String>.createClient(
    websocketConnectionUri, // Postman echo ws server
    textSocketProcessor,
    connectionOptions: connectionOptions,
  );

  // Listening to webSocket status changes
  final socketSub = textSocketHandler.socketStateStream.listen((stateEvent) {
    // ignore: avoid_print
    print('> status changed to ${stateEvent.status}');
  });

  // Listening to server responses:
  final incomingSub = textSocketHandler.incomingMessagesStream.listen((inMsg) {
    // ignore: avoid_print
    print('> webSocket  got text message from server: "$inMsg"');
  });

  // Connecting to server:
  final isTextSocketConnected = await textSocketHandler.connect();
  if (!isTextSocketConnected) {
    // ignore: avoid_print
    print('Connection to [$websocketConnectionUri] failed for some reason!');
    return;
  }
  // Send message to server:
  textSocketHandler.sendMessage(textMessageToServer);

  await Future<void>.delayed(const Duration(seconds: 2));
  // Disconnecting from server:
  await textSocketHandler.disconnect('manual disconnect');
  // Cancelling subscriptions after a small delay:
  await Future<void>.delayed(const Duration(milliseconds: 100));
  socketSub.cancel();
  incomingSub.cancel();
  // Disposing webSocket:
  textSocketHandler.close();
}
