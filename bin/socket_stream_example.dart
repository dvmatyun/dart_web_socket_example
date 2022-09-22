import 'dart:convert';

import 'package:websocket_universal/websocket_universal.dart';

/// Example for websocket article `Part Three`
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

  /// Using `singleEntityTopic` socket topic to listen messages from server
  /// that contain [CustomGameModel] entity as serialized data
  final ISocketTopic singleEntityTopic = SocketTopicImpl.duo(
    host: TestDecoder.host,
    topic1: CustomGameModel.topic1,
  );

  /// Listening to server events for exact `socket topic`
  /// with <CustomGameModel>-typed data: (you can also use dataBridge.getStream)
  final singleEntitySub = dataBridge
      .getResponsesStream<CustomGameModel>(singleEntityTopic)
      .listen((event) {
    // ignore: avoid_print
    print('Stream event at [${event.timestamp}]: ${event.data}');
  });

  /// Emulating 2 messages from server (in fact, server can send us data
  /// without any requests)
  final requestGame = MessageToServer(
    topic: singleEntityTopic,
    data: jsonEncode(
      const CustomGameModel(
        name: 'MakeWorld strategy',
        playersAmount: 8,
      ),
    ),
    error: null,
  );
  final srSingle = SocketRequest(requestMessage: requestGame);

  /// Emulating first message from server:
  dataBridge.requestData(srSingle);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  /// Emulating second message from server:
  dataBridge.requestData(srSingle);
  await Future<void>.delayed(const Duration(milliseconds: 500));

  /// No longer listening to `CustomGameModel` data stream:
  await singleEntitySub.cancel();

  /// Example with grouped data:
  /// Using `entitiesListTopic` socket topic to listen messages from server
  /// that contain [List<CustomGameModel>] entity as serialized data
  final ISocketTopic entitiesListTopic = SocketTopicImpl.duo(
    host: TestDecoder.host,
    topic1: CustomGameModel.topic1List,
  );
  final srMultipleTopics = SocketRequest(
    requestMessage: requestGame,
    responseTopics: {
      singleEntityTopic,
      entitiesListTopic,
    },
  );

  /// Now we are waiting for server to send us 2 messages and only then
  /// the request will be considered completed.
  /// #1 Requesting single entity:
  print('> #1 Requesting single entity;');
  final taskCompositeResp = dataBridge.compositeRequest(srMultipleTopics);

  /// #2 Emulating list response from server:
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
  print('> #2 Emulating list response from server '
      '(should get composite response afterwards);');
  dataBridge.requestData(socketRequestList);

  /// Awaiting composite response:
  final compositeResponse = await taskCompositeResp;

  /// Now we can get data that this request contains
  /// (ofcause, only if server sent it and it was deserialized properly
  /// on previous steps using [ISocketManagerMiddleware])
  final singleEntity = compositeResponse.getData<CustomGameModel>();
  final listEntity = compositeResponse.getData<List<CustomGameModel>>();
  final dataTopics = compositeResponse.dataCached.keys.join(', ');

  // ignore: avoid_print
  print('Got composite response (in ${compositeResponse.msElapsed} ms. '
      'Data topics: [$dataTopics] '
      'singleEntity=$singleEntity '
      'and listEntity=$listEntity');

  await Future<void>.delayed(const Duration(seconds: 3));
  print('Average ping delay to server: ${requestManager.pingDelayMs} ms.');
  // Cancelling subscriptions:
  await singleEntitySub.cancel();
  // Disconnecting from server:
  await socketHandler.disconnect('manual disconnect');
  // Disposing webSocket:
  requestManager.close();
  socketHandler.close();
}
