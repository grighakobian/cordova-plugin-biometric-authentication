var exec = require('cordova/exec');

exports.analyze = function (arg0, arg1, success, error) {
    exec(success, error, 'BiometricAuthentication', 'analyze', [arg0, arg1]);
};
