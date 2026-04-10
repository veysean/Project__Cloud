const { sequelize } = require('./server');

async function main() {
    try {
        await sequelize.sync({ force: false });
        console.log("Database initialized.");
    } catch (err) {
        console.error("Failed to initialize database:", err);
    } finally {
        await sequelize.close();
    }
}

main();
