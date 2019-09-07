import 'controllers/admin_panel_controllers.dart';
import 'controllers/score_board_controller.dart';
import 'firescore.dart';
import 'repositories/account_repository.dart';
import 'services/account_service.dart';
import 'repositories/game_repository.dart';
import 'services/game_service.dart';

class _FirescoreConfig extends Configuration {
    _FirescoreConfig(String path): super.fromFile(File(path));

    DatabaseConfiguration database;
    String jwtSecret;
}

class FirescoreChannel extends ApplicationChannel {

    ManagedContext context;

    AccountRepository accountRepository;
    AccountService accountService;

    GameRepository gameRepository;
    GameService gameService;

    String jwtSecret;

    @override
    Future prepare() async {
        logger.onRecord.listen((rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));

        final config = _FirescoreConfig(options.configurationFilePath);

        final dataModel = ManagedDataModel.fromCurrentMirrorSystem();

        final persistentStore = PostgreSQLPersistentStore.fromConnectionInfo(
                config.database.username,
                config.database.password,
                config.database.host,
                config.database.port,
                config.database.databaseName
        );

        context = ManagedContext(dataModel, persistentStore);

        jwtSecret = config.jwtSecret;

        accountRepository = AccountRepository(context);
        accountService = AccountService(context);

        gameRepository = GameRepository(context);
        gameService = GameService(context);
    }

    @override
    Controller get entryPoint {
        final router = Router();

        router
                .route("/accounts")
                .link(() => CreateAccountController(accountService));

        router
                .route("/admin/account")
                .link(() => Authorizer.basic(AccountPasswordVerifier(accountRepository)))
                .link(() => AdminAccountController(accountRepository));

        router
                .route("/admin/games/[:gameId]")
                .link(() => Authorizer.basic(AccountPasswordVerifier(accountRepository)))
                .link(() => ManageGamesController(accountRepository, gameRepository, gameService));

        router
                .route("/admin/games/:gameId/score_boards/[:scoreBoardId]")
                .link(() => Authorizer.basic(AccountPasswordVerifier(accountRepository)))
                .link(() => ManageScoreBoardController(context, accountRepository));

        router
                .route("/scores/token/:scoreBoardUui")
                .link(() => GetTokenController(jwtSecret));

        router
                .route("/scores")
                .link(() => Authorizer.bearer(JwtVerifier(jwtSecret)))
                .link(() => CreateScoreController(context, jwtSecret));

        router
                .route("/scores/:scoreBoardUui")
                .link(() => ListScoreController(context));

        return router;
    }
}
