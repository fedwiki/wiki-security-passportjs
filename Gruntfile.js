module.exports = function (grunt) {
  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-git-authors');
  grunt.loadNpmTasks('grunt-retire');

  grunt.initConfig({

    browserify: {
      plugin: {
        src: ['client/security.coffee'],
        dest: 'client/security.js',
        options: {
          transform: ['coffeeify'],
          browserifyOptions: {
            extentions: ".coffee"
          }
        }
      }
    },

    watch: {
      all: {
        files: ['client/*.coffee'],
        tasks: ['build']
      }
    },

    retire: {
      node: ['.'],
      options: {packageOnly: true}
    }

  });

  grunt.registerTask('check', ['retire']);
  grunt.registerTask('build', ['browserify']);
  grunt.registerTask('default', ['build']);

};
