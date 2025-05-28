module.exports = {
    apps : [{
        name: 'livestream',
        script: 'node_modules/next/dist/bin/next',
        instances: 'max',
        exec_mode: 'cluster',
        autorestart: true,
        watch: false,
        env: {
            NODE_ENV: 'development'
        },
        env_production: {
            NODE_ENV: 'production'
        }
    }],
};