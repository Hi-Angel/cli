/**
 * Copyright (C) 2022-2024 the Eask authors.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

"use strict";

const path = require('path');
const fs = require('fs');
const readline = require('readline');

exports.command = ['init [files..]'];
exports.desc = 'Initialize project to use Eask';
exports.builder = yargs => yargs
  .positional(
    '[files..]', {
      description: 'files to use with `--from` flag',
      type: 'array',
    })
  .options({
    'from': {
      description: 'build from an existing package',
      requiresArg: true,
      type: 'string',
      group: TITLE_CMD_OPTION,
    },
  });

exports.handler = async (argv) => {
  if (argv.from) {
    switch (argv.from) {
    case 'cask':
    case 'eldev':
    case 'keg':
    case 'source':
      await UTIL.e_call(argv, 'init/' + argv.from
                        , UTIL.def_flag(argv.from, '--from', argv.from)
                        , argv.files);
      break;
    default:
      console.warn(`Invalid argument, from: ${argv.from}`);
      break;
    }
  } else {
    await create_eask_file();
  }
};

var instance;  /* `readline` instance */

async function create_eask_file(dir) {
  let basename = path.basename(process.cwd());
  instance = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  let new_name = path.join(process.cwd(), 'Eask');

  // Search for existing Eask-files!
  let files = fs.readdirSync(process.cwd()).filter(fn => fn.match('Eask'));
  let continue_op = false;

  if (files.length != 0) {
    // Print out all existing Eask-files, and ask for continuation!
    console.log('Eask-file is already exists,');
    console.log('');
    for (let index in files) {
      console.log('   ' + path.join(process.cwd(), files[index]));
    }
    console.log('');
    await ask(`Continue the creation? (yes) `, (answer) => { continue_op = answer; });

    // Abort if declined!
    if (continue_op != '' && continue_op != 'yes') {
      process.exit(0);
    }

    // Ask for new name unitl the filename is available!
    let new_basename = path.basename(new_name);
    let invalid_name = false;

    // Ask for new name until we found one that meets our requirements!
    while (fs.existsSync(new_name) || invalid_name) {
      let prompt;

      // Handle invalid file name!
      if (invalid_name) {
        prompt = `[?] Invalid filename '${new_basename}', `;
      } else {
        prompt = `[?] Filename '${new_basename}' already taken, `;
      }

      // Ask for new name!
      await ask(prompt + `try another one: `,
                (answer) => {
                  new_name = path.join(process.cwd(), answer);
                  new_basename = answer;
                  invalid_name = !check_eask_filename(answer);
                });
    }
  }

  // Starting writing Eask-file!
  let name, version, description, entry_point, emacs_version, website_url, keywords;

  let guessed_package_name = guess_package_name(basename);
  let guessed_entry_point = guess_entry_point(basename);

  await ask(`package name: (${guessed_package_name}) `, (answer) => {
    name = answer || guessed_package_name;
  });
  await ask(`version: (1.0.0) `, (answer) => { version = answer || '1.0.0'; });
  await ask(`description: `, (answer) => { description = answer; });
  await ask(`entry point: (${guessed_entry_point}) `, (answer) => {
    entry_point = answer || guessed_entry_point;
  });
  await ask(`emacs version: (26.1) `, (answer) => { emacs_version = answer || '26.1'; });
  await ask(`website: `, (answer) => { website_url = answer; });
  await ask(`keywords: `, (answer) => { keywords = answer; });

  name          = remove_double_quotes(name);
  version       = remove_double_quotes(version);
  description   = remove_double_quotes(description);
  entry_point   = remove_double_quotes(entry_point);
  emacs_version = remove_double_quotes(emacs_version);
  website_url   = remove_double_quotes(website_url);
  keywords      = remove_double_quotes(keywords);

  keywords = keywords.split(/[, ]+/).join('" "');

  let content = `(package "${name}"
         "${version}"
         "${description}")

(website-url "${website_url}")
(keywords "${keywords}")

(package-file "${entry_point}")

(script "test" "echo \\\"Error: no test specified\\\" && exit 1")

(source "gnu")

(depends-on "emacs" "${emacs_version}")
`;

  await ask(`About to write to ${new_name}:

${content}

Is this OK? (yes) `,
            (answer) => {
              if (answer == '' || answer == 'yes') {
                fs.writeFile(new_name, content, (err) => { if (err) console.log(err); });
              }
            });
  instance.close();
}

/**
 * Ask question with callback
 * @param { string } question - question to ask for user input
 * @param { callback } callback - callback with user's answer
 */
function ask(question, callback) {
  return new Promise((resolve, reject) => {
    instance.question(question, (answer) => { callback(answer); resolve(); });
  });
}

/**
 * Return true if NAME is a valid Eask-file filename.
 * @param { string } name - either a filename or file path.
 * @return { boolean } - True for valid filename.
 */
function check_eask_filename(name) {
  let base = path.basename(name);
  let prefix;
  if (base.startsWith('Easkfile')) prefix = 'Easkfile';
  else if (base.startsWith('Eask')) prefix = 'Eask';
  else return false;
  let suffix = base.replace(prefix, '');
  return suffix == '' || /^[.][0-9]/.test(suffix);
}

/**
 * Return the guessed project name by its basename.
 * @param { String } basename - The working directory name.
 * @return Guessed project name.
 */
function guess_package_name(basename) {
  basename = basename.toLowerCase();
  basename = basename.replaceAll('emacs-', '');
  basename = basename.replaceAll('-emacs', '');
  basename = basename.replace(/[-.]el$/, '');
  return basename;
}

/**
 * Return the guessed entry point by its basname.
 * @param { String } basename - The working directory name.
 * @return Guessed entry point filename.
 */
function guess_entry_point(basename) {
  basename = guess_package_name(basename);
  return basename + ".el";
}

/**
 * Remove all double quotes from string.
 * @param { String } str - String to remove all double quotes.
 * @return String has been removed all double quotes.
 */
function remove_double_quotes(str) {
  return str.replaceAll('\"', '');
}

/*
 * Module Exports
 */
module.exports.create_eask_file = create_eask_file;
