import 'dart:convert';
import 'package:firescore/model/account.dart';
import 'package:firescore/repositories/account_repository.dart';
import 'package:firescore/repositories/game_repository.dart';
import 'data_creator_helper/accounts_creator.dart';
import 'data_creator_helper/games_creator.dart';
import 'harness/app.dart';

Future main() async {
  final harness = Harness()..install();

  String _generateAuthorizaiton(Account account) {
    return base64.encode(utf8.encode("${account.email}:${account.password}"));
  }

  test("GET /admin/account returns the ScoreBoard token", () async {
    final insertedAccount =  await AccountsCreator(harness.application.channel.context).createAccount();
    final authentication = _generateAuthorizaiton(insertedAccount);

    expectResponse(await harness.agent.get("/admin/account", headers: {
      "Authorization": "Basic $authentication",
    }), 200,
        body: {
          "id": insertedAccount.id,
          "email": insertedAccount.email,
        }
    );
  });

  test("POST /accounts creates a new account", () async {
    await harness.agent.post("/accounts", body: {
      "email": "bla@bla.com",
      "password": "123password",
    });

    final accounts = await AccountRepository(harness.application.channel.context).fetchAll();
    expect(accounts.length, equals(1));
  });

  test("POST /admin/games creates a new game", () async {
    final insertedAccount =  await AccountsCreator(harness.application.channel.context).createAccount();
    final authentication = _generateAuthorizaiton(insertedAccount);

    expectResponse(await harness.agent.post("/admin/games", body: { "name": "BGUG" }, headers: {
      "Authorization": "Basic $authentication",
    }), 200,
        body: {
          "id": 1,
          "name": "BGUG",
          "account": { "id": insertedAccount.id }
        }
    );
  });

  test("GET /admin/games lists all the games from that account", () async {
    final insertedAccount =  await AccountsCreator(harness.application.channel.context).createAccount();
    final authentication = _generateAuthorizaiton(insertedAccount);

    final bgug = await GamesCreator(harness.application.channel.context).createGame(insertedAccount, name: "BGUG");
    final bob = await GamesCreator(harness.application.channel.context).createGame(insertedAccount, name: "Bob Box");

    expectResponse(await harness.agent.get("/admin/games", headers: {
      "Authorization": "Basic $authentication",
    }), 200,
        body: [{
          "id": bgug.id,
          "name": "BGUG",
          "account": { "id": insertedAccount.id }
        }, {
          "id": bob.id,
          "name": "Bob Box",
          "account": { "id": insertedAccount.id }
        }]
    );
  });

  test("DELETE /admin/games/:gameId deletes a game", () async {
    final insertedAccount =  await AccountsCreator(harness.application.channel.context).createAccount();
    final authentication = _generateAuthorizaiton(insertedAccount);

    final context = harness.application.channel.context;
    final bgug = await GamesCreator(context).createGame(insertedAccount, name: "BGUG");
    await GamesCreator(context).createGame(insertedAccount, name: "Bob Box");

    await harness.agent.delete("/admin/games/${bgug.id}", headers: {
      "Authorization": "Basic $authentication",
    });

    final games = await GameRepository(context).fetchGamesFromAccount(insertedAccount);
    expect(games.length, equals(1));
  });
}