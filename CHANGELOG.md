# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased] - [unreleased]
### Changed
### Removed
### Fixed

## [0.3.0] - 04-02-2020
### Changed
    * counter-type regulators from an ETS-centered solution to dedicated `gen_server` processes
### Removed
    * OTP 17 support
### Fixed
    * unrecoverable loss of slots in counter-type regulators upon their limit being reached
    * unrecoverable loss of slots in counter-type regulators upon slot owners being brutally killed

## [0.2.1] - 30-01-2019
### Fixed
    * [Prevent warnings about non-documented type values](https://github.com/lrascao/raterl/pull/7)
    * Deprecate R16 Travis tests

## [0.2.0] - 12-02-2018
### Fixed
    * Don't crash on boot upon lack of explicit env. config
### Added
    * Ability of adding/removing/reconfiguring queues in runtime

## [0.1.3] - 07-01-2018
### Added
### Changed
### Fixed
    * Fill out hex bureaucracy

## [0.1.2] - 07-01-2018
### Added
### Changed
    * Make README a bit more consistent
### Fixed

## [0.1.1] - 03-08-2017
### Added
    * Continuous integration
### Changed
### Fixed
    * Avoid canceling timer when modifying the regulator

## [0.1.0] - 10-02-2016
### Added
    * First version
### Changed
### Fixed
