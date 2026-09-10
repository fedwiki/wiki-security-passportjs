module.exports = function (grunt) {
  grunt.loadNpmTasks("grunt-browserify");
  grunt.loadNpmTasks("grunt-git-authors");

  grunt.initConfig({
    browserify: {
      plugin: {
        src: ["client/security.coffee"],
        dest: "client/security.js",
        options: {
          transform: ["coffeeify"],
          browserifyOptions: {
            extentions: ".coffee",
          },
        },
      },
    },
  });

  grunt.registerTask("build", ["browserify"]);
  grunt.registerTask("default", ["build"]);
};
