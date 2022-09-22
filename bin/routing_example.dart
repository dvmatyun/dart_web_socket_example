import 'dart:convert';

import 'package:websocket_universal/websocket_universal.dart';

/// Example for websocket article `Part Two`
void main() async {
  /// Postman echo ws server (you can use your own server URI)
  const websocketConnectionUri = 'wss://ws.postman-echo.com/raw';
  const connectionOptions = SocketConnectionOptions();

  /// Complex example:
  /// Example using [ISocketMessage] and [IMessageToServer]
  /// (recommended for applications, server must deserialize
  /// [ISocketMessage] serialized string to [ISocketMessage] object)
  final IMessageProcessor<ISocketMessage<Object?>, IMessageToServer>
      messageProcessor = SocketMessageProcessor();
  final socketHandler =
      IWebSocketHandler<ISocketMessage<Object?>, IMessageToServer>.createClient(
    websocketConnectionUri,
    messageProcessor,
    connectionOptions: connectionOptions,
  );

  /// Creating websocket_manager:
  /// `ISocketManagerMiddleware` processes requests before sending and
  /// after receiving ISocketMessage. See test implementation for details.
  final ISocketManagerMiddleware middleware = SocketManagerMiddleware();
  final IWebSocketRequestManager requestManager = WebSocketRequestManager(
    middleware: middleware,
    webSocketHandler: socketHandler,
  );
  final IWebSocketDataBridge dataBridge = WebSocketDataBridge(requestManager);

  ///
  // Connecting to server:
  final isConnected = await socketHandler.connect();

  if (!isConnected) {
    // ignore: avoid_print
    print('Connection to [$websocketConnectionUri] failed for some reason!');
    return;
  }

  // Sending message with routing path 'test/game' and simple JSON payload:
  final requestGame = MessageToServer.duo(
    host: TestDecoder.host,
    topic1: CustomGameModel.topic1,
    data: jsonEncode(
      const CustomGameModel(
        name: 'MakeWorld strategy',
        playersAmount: 8,
      ),
    ),
    error: null,
  );
  final socketRequest = SocketRequest.mirror(requestMessage: requestGame);

  final result =
      await dataBridge.singleRequestFull<CustomGameModel>(socketRequest);
  // ignore: avoid_print
  print('Got result: ${result.data}');

  /// Example with list (path 'test/game-list'):
  final outMsgList = MessageToServer.duo(
    host: TestDecoder.host,
    topic1: CustomGameModel.topic1List,
    data: jsonEncode([
      const CustomGameModel(
        name: 'MakeWorld strategy',
        playersAmount: 8,
      ),
      const CustomGameModel(
        name: 'New patch',
        playersAmount: 4,
      ),
    ]),
    error: null,
  );
  final socketRequestList = SocketRequest.mirror(requestMessage: outMsgList);

  final listResult = await dataBridge
      .singleRequestFull<List<CustomGameModel>>(socketRequestList);
  // ignore: avoid_print
  print('Got list result: ${listResult.data}');

  await Future<void>.delayed(const Duration(seconds: 3));
  // Disconnecting from server:
  await socketHandler.disconnect('manual disconnect');
  // Disposing webSocket:
  requestManager.close();
  socketHandler.close();
}
