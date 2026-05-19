#include <Interpreters/InterpreterDropIndexQuery.h>
#include <Interpreters/InterpreterAlterQuery.h>
#include <Interpreters/InterpreterFactory.h>
#include <Interpreters/Context.h>

<<<<<<< HEAD
#if DATASTORE_CLOUD
#include <Interpreters/SharedDatabaseCatalog.h>
#endif
=======
#include <Parsers/ASTAlterQuery.h>
#include <Parsers/ASTDropIndexQuery.h>
>>>>>>> v26.3.10.62-lts

namespace DB
{

namespace
{

ASTPtr rewriteToAlterTable(const ASTDropIndexQuery & query)
{
    auto alter = make_intrusive<ASTAlterQuery>();
    alter->alter_object = ASTAlterQuery::AlterObjectType::TABLE;
    alter->setDatabase(query.getDatabase());
    alter->setTable(query.getTable());
    alter->cluster = query.cluster;

    auto command_list = make_intrusive<ASTExpressionList>();
    command_list->children.push_back(query.convertToASTAlterCommand());

    alter->command_list = command_list.get();
    alter->children.push_back(std::move(command_list));

    return alter;
}

}

BlockIO InterpreterDropIndexQuery::execute()
{
    const auto & drop_index = query_ptr->as<ASTDropIndexQuery &>();
    const auto context = Context::createCopy(getContext());

<<<<<<< HEAD
    AccessRightsElements required_access;
    required_access.emplace_back(AccessType::ALTER_DROP_INDEX, drop_index.getDatabase(), drop_index.getTable());

    if (!drop_index.cluster.empty())
    {
        DDLQueryOnClusterParams params;
        params.access_to_check = std::move(required_access);
        return executeDDLQueryOnCluster(query_ptr, current_context, params);
    }

    current_context->checkAccess(required_access);
    auto table_id = current_context->resolveStorageID(drop_index, Context::ResolveOrdinary);
    query_ptr->as<ASTDropIndexQuery &>().setDatabase(table_id.database_name);

    DatabasePtr database = DatabaseCatalog::instance().getDatabase(table_id.database_name);
    if (database->shouldReplicateQuery(getContext(), query_ptr))
    {
        auto guard = DatabaseCatalog::instance().getDDLGuard(table_id.database_name, table_id.table_name, database.get());
        guard->releaseTableLock();
        return database->tryEnqueueReplicatedDDL(query_ptr, current_context, {}, std::move(guard));
    }

#if DATASTORE_CLOUD
    if (SharedDatabaseCatalog::shouldReplicateQuery(getContext(), query_ptr))
    {
        return SharedDatabaseCatalog::instance().tryExecuteDDLQuery(query_ptr, getContext());
    }
#endif

    StoragePtr table = DatabaseCatalog::instance().getTable(table_id, current_context);
    if (table->isStaticStorage())
        throw Exception(ErrorCodes::TABLE_IS_READ_ONLY, "Table is read-only");

    /// Convert ASTDropIndexQuery to AlterCommand.
    AlterCommands alter_commands;

    AlterCommand command;
    command.ast = drop_index.convertToASTAlterCommand();
    command.type = AlterCommand::DROP_INDEX;
    command.index_name = drop_index.index_name->as<ASTIdentifier &>().name();
    command.if_exists = drop_index.if_exists;

    alter_commands.emplace_back(std::move(command));

    auto alter_lock = table->lockForAlter(current_context->getSettingsRef()[Setting::lock_acquire_timeout]);
    StorageInMemoryMetadata metadata = table->getInMemoryMetadata();
    alter_commands.validate(table, current_context);
    alter_commands.prepare(metadata);
    table->checkAlterIsPossible(alter_commands, current_context);
    table->alter(alter_commands, current_context, alter_lock);

    return {};
=======
    auto alter_query = rewriteToAlterTable(drop_index);
    return InterpreterAlterQuery(alter_query, context).execute();
>>>>>>> v26.3.10.62-lts
}

void registerInterpreterDropIndexQuery(InterpreterFactory & factory)
{
    auto create_fn = [] (const InterpreterFactory::Arguments & args)
    {
        return std::make_unique<InterpreterDropIndexQuery>(args.query, args.context);
    };
    factory.registerInterpreter("InterpreterDropIndexQuery", create_fn);
}

}
