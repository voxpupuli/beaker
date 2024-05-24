# Changelog

## [6.0.0](https://github.com/voxpupuli/beaker/tree/6.0.0) (2024-05-24)

**Breaking changes:**

- Drop EoL F5 support [\#1866](https://github.com/voxpupuli/beaker/pull/1866) ([bastelfreak](https://github.com/bastelfreak))
- Drop EoL cumulus support [\#1867](https://github.com/voxpupuli/beaker/pull/1867) ([bastelfreak](https://github.com/bastelfreak))
- drop sys-v leftovers; assume systemctl is available for unknown platforms [\#1868](https://github.com/voxpupuli/beaker/pull/1868) ([bastelfreak](https://github.com/bastelfreak))
- Drop EoL huaweios support [\#1869](https://github.com/voxpupuli/beaker/pull/1869) ([bastelfreak](https://github.com/bastelfreak))
- Drop EoL EL4 support [\#1870](https://github.com/voxpupuli/beaker/pull/1870) ([bastelfreak](https://github.com/bastelfreak))
- Drop support for EoL Debian/Ubuntu versions [\#1871](https://github.com/voxpupuli/beaker/pull/1871) ([bastelfreak](https://github.com/bastelfreak))
- Drop EoL cisco support [\#1872](https://github.com/voxpupuli/beaker/pull/1872) ([bastelfreak](https://github.com/bastelfreak))
- Drop Fedora < 22 support [\#1873](https://github.com/voxpupuli/beaker/pull/1873) ([ekohl](https://github.com/ekohl))
- Drop EoL Arista EOS support [\#1874](https://github.com/voxpupuli/beaker/pull/1874) ([bastelfreak](https://github.com/bastelfreak))
- drop validate_setup method [\#1875](https://github.com/voxpupuli/beaker/pull/1875) ([bastelfreak](https://github.com/bastelfreak))
- Drop EoL netscaler support [\#1876](https://github.com/voxpupuli/beaker/pull/1876) ([bastelfreak](https://github.com/bastelfreak))

**Implemented enhancements:**

- Add package logic for Amazon Linux 2 [\#1884](https://github.com/voxpupuli/beaker/pull/1884) ([mhashizume](https://github.com/mhashizume))

**Fixed bugs:**

- Add ssh restart for Ubuntu [\#1885](https://github.com/voxpupuli/beaker/pull/1885) ([skyamgarp](https://github.com/skyamgarp))

## [5.8.1](https://github.com/voxpupuli/beaker/tree/5.8.1) (2024-05-06)

**Fixed bugs:**

- Add extension parameter to parent tmpfile method signature [\#1863](https://github.com/voxpupuli/beaker/pull/1863) ([ekohl](https://github.com/ekohl))

## [5.8.0](https://github.com/voxpupuli/beaker/tree/5.8.0) (2024-03-23)

**Implemented enhancements:**

- Add Ruby 3.3 support [\#1859](https://github.com/voxpupuli/beaker/pull/1859) ([bastelfreak](https://github.com/bastelfreak))
- Do not attempt to install curl on DNF-based distros [\#1854](https://github.com/voxpupuli/beaker/pull/1854) ([ekohl](https://github.com/ekohl))
- PE-37978: Add 'amazon' to #repo-filename method [\#1858](https://github.com/voxpupuli/beaker/pull/1858) ([span786](https://github.com/span786))

**Fixed bugs:**

- CLI: Fix typo: opton->option [\#1849](https://github.com/voxpupuli/beaker/pull/1849) ([bastelfreak](https://github.com/bastelfreak))

**Others:**

- build(deps-dev): update voxpupuli-rubocop requirement from ~> 2.4.0 to ~> 2.6.0 [\#1850](https://github.com/voxpupuli/beaker/pull/1850) (dependabot)

## [5.7.0](https://github.com/voxpupuli/beaker/tree/5.7.0) (2024-02-13)

**Implemented enhancements:**

- Add Ubuntu 24.04 noble codename [\#1847](https://github.com/voxpupuli/beaker/pull/1847) ([h0tw1r3](https://github.com/h0tw1r3))

## [5.6.0](https://github.com/voxpupuli/beaker/tree/5.6.0) (2023-11-23)

**Implemented enhancements:**

- Use DNF for Amazon Linux 2023 [\#1832](https://github.com/voxpupuli/beaker/pull/1832) ([mhashizume](https://github.com/mhashizume))
- Use DNF for Fedora, newer Enterprise Linux [\#1835](https://github.com/voxpupuli/beaker/pull/1835) ([mhashizume](https://github.com/mhashizume))

**Fixed bugs:**

- Permit PlatformTagContainer class for beaker hosts [\#1833](https://github.com/voxpupuli/beaker/pull/1833) ([tlehman](https://github.com/tlehman))

## [5.5.0](https://github.com/voxpupuli/beaker/tree/5.5.0) (2023-10-02)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.4.0...5.5.0)

**Implemented enhancements:**

- Allow amazon as a platform [\#1824](https://github.com/voxpupuli/beaker/pull/1824) ([yachub](https://github.com/yachub))

## [5.4.0](https://github.com/voxpupuli/beaker/tree/5.4.0) (2023-09-12)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.3.0...5.4.0)

**Implemented enhancements:**

- \(RE-15540\) Add Debian 12\/13\/14 support [\#1822](https://github.com/voxpupuli/beaker/pull/1822) ([yachub](https://github.com/yachub))

## [5.3.1](https://github.com/voxpupuli/beaker/tree/5.3.1) (2023-07-26)

**Fixed bugs:**

- Fix Minitest capitalization [\#1819](https://github.com/voxpupuli/beaker/pull/1819) ([mhashizume](https://github.com/mhashizume))

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.3.0...5.3.1)

## [5.3.0](https://github.com/voxpupuli/beaker/tree/5.3.0) (2023-06-06)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.2.0...5.3.0)

**Implemented enhancements:**

- Add bcrypt\_pbkdf to fix ed25519 ssh keys support [\#1810](https://github.com/voxpupuli/beaker/pull/1810) ([jay7x](https://github.com/jay7x))

**Merged pull requests:**

- rubocop: autofix [\#1816](https://github.com/voxpupuli/beaker/pull/1816) ([bastelfreak](https://github.com/bastelfreak))
- GCG: Add missing faraday dependency [\#1815](https://github.com/voxpupuli/beaker/pull/1815) ([bastelfreak](https://github.com/bastelfreak))
- Build gems with verbosity and strictness [\#1811](https://github.com/voxpupuli/beaker/pull/1811) ([bastelfreak](https://github.com/bastelfreak))

## [5.2.0](https://github.com/voxpupuli/beaker/tree/5.2.0) (2023-04-28)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.1.0...5.2.0)

**Implemented enhancements:**

- Declare API interface on Beaker::Host [\#1806](https://github.com/voxpupuli/beaker/pull/1806) ([ekohl](https://github.com/ekohl))
- Switch to voxpupuli-rubocop [\#1804](https://github.com/voxpupuli/beaker/pull/1804) ([bastelfreak](https://github.com/bastelfreak))
- Support an extension to tmpfile [\#1735](https://github.com/voxpupuli/beaker/pull/1735) ([ekohl](https://github.com/ekohl))

**Fixed bugs:**

- Use systemctl to restart SSH on EL9 [\#1808](https://github.com/voxpupuli/beaker/pull/1808) ([ekohl](https://github.com/ekohl))

**Closed issues:**

- Failed to exec 'vagrant up' \(rbenv, ruby 2.7.6, bundler 2.3.19, virtualbox\) [\#1752](https://github.com/voxpupuli/beaker/issues/1752)
- EL 9 error - /sbin/service: No such file or directory [\#1751](https://github.com/voxpupuli/beaker/issues/1751)

**Merged pull requests:**

- Disable RSpec/IndexedLet [\#1807](https://github.com/voxpupuli/beaker/pull/1807) ([ekohl](https://github.com/ekohl))
- Drop legacy yard tasks [\#1805](https://github.com/voxpupuli/beaker/pull/1805) ([bastelfreak](https://github.com/bastelfreak))
- Enhance documentation about roles [\#1800](https://github.com/voxpupuli/beaker/pull/1800) ([rwaffen](https://github.com/rwaffen))

## [5.1.0](https://github.com/voxpupuli/beaker/tree/5.1.0) (2023-03-27)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/5.0.0...5.1.0)

**Implemented enhancements:**

- Introduce shareable rubocop config [\#1795](https://github.com/voxpupuli/beaker/pull/1795) ([bastelfreak](https://github.com/bastelfreak))

## [5.0.0](https://github.com/voxpupuli/beaker/tree/5.0.0) (2023-03-24)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.39.0...5.0.0)

**Breaking changes:**

- Remove install\_puppet\_agent\_\* methods [\#1775](https://github.com/voxpupuli/beaker/pull/1775) ([ekohl](https://github.com/ekohl))
- Update fakefs requirement from ~\> 1.0 to ~\> 2.4 [\#1770](https://github.com/voxpupuli/beaker/pull/1770) ([dependabot[bot]](https://github.com/apps/dependabot))
- Drop deprecated methods [\#1769](https://github.com/voxpupuli/beaker/pull/1769) ([ekohl](https://github.com/ekohl))
- Drop Ruby 2.4/2.5/2.6 support [\#1767](https://github.com/voxpupuli/beaker/pull/1767) ([bastelfreak](https://github.com/bastelfreak))
- \(maint\) Removes open\_uri\_redirections [\#1764](https://github.com/voxpupuli/beaker/pull/1764) ([mhashizume](https://github.com/mhashizume))
- Remove add-el-extras, passenger, proxy\_config, disable\_iptables and clean up code [\#1731](https://github.com/voxpupuli/beaker/pull/1731) ([ekohl](https://github.com/ekohl))

**Implemented enhancements:**

- Drop rspec-its dependency in favor of have\_attributes [\#1788](https://github.com/voxpupuli/beaker/pull/1788) ([ekohl](https://github.com/ekohl))
- Add Ruby 3.2 support [\#1762](https://github.com/voxpupuli/beaker/pull/1762) ([ekohl](https://github.com/ekohl))

**Fixed bugs:**

- 4.39.0 breaks beaker-puppet tests [\#1772](https://github.com/voxpupuli/beaker/issues/1772)

**Merged pull requests:**

- Use send instead of instance\_eval [\#1793](https://github.com/voxpupuli/beaker/pull/1793) ([ekohl](https://github.com/ekohl))
- rubocop: Fix more Style cops [\#1792](https://github.com/voxpupuli/beaker/pull/1792) ([bastelfreak](https://github.com/bastelfreak))
- Rubocop: Fix more Style cops [\#1791](https://github.com/voxpupuli/beaker/pull/1791) ([bastelfreak](https://github.com/bastelfreak))
- Rubocop: Fix multiple Layout cops [\#1790](https://github.com/voxpupuli/beaker/pull/1790) ([bastelfreak](https://github.com/bastelfreak))
- Add a CI job we can enforce in branch protection [\#1789](https://github.com/voxpupuli/beaker/pull/1789) ([bastelfreak](https://github.com/bastelfreak))
- rubocop: disable Gemspec/DevelopmentDependencies [\#1787](https://github.com/voxpupuli/beaker/pull/1787) ([bastelfreak](https://github.com/bastelfreak))
- Release pipeline: Dont install optional gems [\#1786](https://github.com/voxpupuli/beaker/pull/1786) ([bastelfreak](https://github.com/bastelfreak))
- CI: Run on merges to master [\#1785](https://github.com/voxpupuli/beaker/pull/1785) ([bastelfreak](https://github.com/bastelfreak))
- Run acceptance tests in CI [\#1784](https://github.com/voxpupuli/beaker/pull/1784) ([ekohl](https://github.com/ekohl))
- Update in-parallel requirement from ~\> 0.1 to \>= 0.1, \< 2.0 [\#1783](https://github.com/voxpupuli/beaker/pull/1783) ([dependabot[bot]](https://github.com/apps/dependabot))
- Update rubocop-rspec requirement from ~\> 2.18.1 to ~\> 2.19.0 [\#1781](https://github.com/voxpupuli/beaker/pull/1781) ([dependabot[bot]](https://github.com/apps/dependabot))
- Update rubocop requirement from ~\> 1.47.0 to ~\> 1.48.0 [\#1780](https://github.com/voxpupuli/beaker/pull/1780) ([dependabot[bot]](https://github.com/apps/dependabot))
- dependabot: check for github actions as well [\#1779](https://github.com/voxpupuli/beaker/pull/1779) ([bastelfreak](https://github.com/bastelfreak))
- RuboCop: Fix Layout cops [\#1778](https://github.com/voxpupuli/beaker/pull/1778) ([bastelfreak](https://github.com/bastelfreak))
- Fix more rubocop violations [\#1777](https://github.com/voxpupuli/beaker/pull/1777) ([bastelfreak](https://github.com/bastelfreak))
- Use Enumerable\#all? [\#1776](https://github.com/voxpupuli/beaker/pull/1776) ([ekohl](https://github.com/ekohl))
- Do not include Unix::Exec on Windows::Exec tests [\#1774](https://github.com/voxpupuli/beaker/pull/1774) ([ekohl](https://github.com/ekohl))
- Update rubocop requirement from ~\> 1.45.0 to ~\> 1.47.0 [\#1773](https://github.com/voxpupuli/beaker/pull/1773) ([dependabot[bot]](https://github.com/apps/dependabot))
- rubocop: Fix commas and whitespace and newlines [\#1768](https://github.com/voxpupuli/beaker/pull/1768) ([bastelfreak](https://github.com/bastelfreak))
- CI: Use latest actions/checkout version [\#1766](https://github.com/voxpupuli/beaker/pull/1766) ([bastelfreak](https://github.com/bastelfreak))

## [4.39.0](https://github.com/voxpupuli/beaker/tree/4.39.0) (2023-02-18)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.38.1...4.39.0)

**Implemented enhancements:**

- \(maint\) StringInclude Rubocop corrections [\#1765](https://github.com/voxpupuli/beaker/pull/1765) ([mhashizume](https://github.com/mhashizume))
- Add Rubocop [\#1761](https://github.com/voxpupuli/beaker/pull/1761) ([ekohl](https://github.com/ekohl))

**Fixed bugs:**

- Extend list of permitted classes for YAML safe load and allow aliases [\#1758](https://github.com/voxpupuli/beaker/pull/1758) ([nmburgan](https://github.com/nmburgan))

**Closed issues:**

- Ruby 3.1/Psych 4 compatibility issues [\#1753](https://github.com/voxpupuli/beaker/issues/1753)

**Merged pull requests:**

- Update net-scp requirement from \>= 1.2, \< 4.0 to \>= 1.2, \< 5.0 [\#1757](https://github.com/voxpupuli/beaker/pull/1757) ([dependabot[bot]](https://github.com/apps/dependabot))

## [4.38.1](https://github.com/voxpupuli/beaker/tree/4.38.1) (2022-09-21)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.38.0...4.38.1)

**Fixed bugs:**

- Arch Linux: Ensure keyring is up2date [\#1755](https://github.com/voxpupuli/beaker/pull/1755) ([bastelfreak](https://github.com/bastelfreak))

## [4.38.0](https://github.com/voxpupuli/beaker/tree/4.38.0) (2022-08-11)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.37.2...4.38.0)

**Implemented enhancements:**

- Drop pry dependency, allow using debug gem [\#1737](https://github.com/voxpupuli/beaker/pull/1737) ([ekohl](https://github.com/ekohl))

## [4.37.2](https://github.com/voxpupuli/beaker/tree/4.37.2) (2022-07-29)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.37.1...4.37.2)

**Fixed bugs:**

- Use the new scheme for agent versions \>= 6.28 and \< 7 [\#1749](https://github.com/voxpupuli/beaker/pull/1749) ([joshcooper](https://github.com/joshcooper))

## [4.37.1](https://github.com/voxpupuli/beaker/tree/4.37.1) (2022-07-27)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.37.0...4.37.1)

**Fixed bugs:**

- macOS PE tarballs include arch now [\#1747](https://github.com/voxpupuli/beaker/pull/1747) ([joshcooper](https://github.com/joshcooper))

## [4.37.0](https://github.com/voxpupuli/beaker/tree/4.37.0) (2022-06-28)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.36.1...4.37.0)

**Implemented enhancements:**

- Add support for Win32-OpenSSH [\#1744](https://github.com/voxpupuli/beaker/pull/1744) ([joshcooper](https://github.com/joshcooper))

**Fixed bugs:**

- Create ~/.ssh on Windows if it doesn't exist [\#1745](https://github.com/voxpupuli/beaker/pull/1745) ([joshcooper](https://github.com/joshcooper))

## [4.36.1](https://github.com/voxpupuli/beaker/tree/4.36.1) (2022-06-16)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.36.0...4.36.1)

**Implemented enhancements:**

- \(maint\) Remove /etc/environment file for ubuntu2204 [\#1742](https://github.com/voxpupuli/beaker/pull/1742) ([cthorn42](https://github.com/cthorn42))

## [4.36.0](https://github.com/voxpupuli/beaker/tree/4.36.0) (2022-05-30)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.35.0...4.36.0)

**Implemented enhancements:**

- \(PE-33493\) Add Ubuntu 2204 codename [\#1740](https://github.com/voxpupuli/beaker/pull/1740) ([cthorn42](https://github.com/cthorn42))

## [4.35.0](https://github.com/voxpupuli/beaker/tree/4.35.0) (2022-05-13)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.34.0...4.35.0)

**Implemented enhancements:**

- Build gem during CI runs [\#1738](https://github.com/voxpupuli/beaker/pull/1738) ([bastelfreak](https://github.com/bastelfreak))
- Add Ruby 3.1 support [\#1736](https://github.com/voxpupuli/beaker/pull/1736) ([ekohl](https://github.com/ekohl))

## [4.34.0](https://github.com/voxpupuli/beaker/tree/4.34.0) (2022-01-27)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.33.0...4.34.0)

**Implemented enhancements:**

- Extract a host\_packages method from validate\_host [\#1729](https://github.com/voxpupuli/beaker/pull/1729) ([ekohl](https://github.com/ekohl))
- Reduce duplication in ssh\_permit\_user\_environment [\#1728](https://github.com/voxpupuli/beaker/pull/1728) ([ekohl](https://github.com/ekohl))

**Fixed bugs:**

- Do not install curl on EL9 [\#1732](https://github.com/voxpupuli/beaker/pull/1732) ([ekohl](https://github.com/ekohl))
- Drop old Ruby 1.8 compatibility code [\#1730](https://github.com/voxpupuli/beaker/pull/1730) ([ekohl](https://github.com/ekohl))

## [4.33.0](https://github.com/voxpupuli/beaker/tree/4.33.0) (2022-01-21)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.32.0...4.33.0)

**Implemented enhancements:**

- Add ed25519 as runtime dependency [\#1726](https://github.com/voxpupuli/beaker/pull/1726) ([bastelfreak](https://github.com/bastelfreak))

## [4.32.0](https://github.com/voxpupuli/beaker/tree/4.32.0) (2021-12-06)

[Full Changelog](https://github.com/voxpupuli/beaker/compare/4.31.0...4.32.0)

**Implemented enhancements:**

- Initial EL9 support [\#1719](https://github.com/voxpupuli/beaker/pull/1719) ([ekohl](https://github.com/ekohl))

**Fixed bugs:**

- Arch Linux: install net-tools and openssh [\#1722](https://github.com/voxpupuli/beaker/pull/1722) ([bastelfreak](https://github.com/bastelfreak))

## [4.31.0](https://github.com/voxpupuli/beaker/tree/4.31.0) (2021-11-02)

### Fixed

- (BKR-1690) Fix localhost logging ([#1691](https://github.com/voxpupuli/beaker/pull/1691))

### Added

- Made fips_check? more generally applicable ([#1717]https://github.com/voxpupuli/beaker/pull/1717))

## [4.30.0](https://github.com/voxpupuli/beaker/tree/4.30.0) (2021-07-21)

### Fixed

- Fix Platform version string comparison for install_local_package ([#1712](https://github.com/voxpupuli/beaker/pull/1712))

### Added

- Add initial opensuse support ([#1697](https://github.com/voxpupuli/beaker/pull/1697))
- Implement codecov reporting ([#1710](https://github.com/voxpupuli/beaker/pull/1710))

### Changed

- beaker-abs: allow latest releases ([#1706](https://github.com/voxpupuli/beaker/pull/1706))
- Align release setup with other gems ([#1707](https://github.com/voxpupuli/beaker/pull/1707))

## [4.29.1](https://github.com/voxpupuli/beaker/tree/4.29.1) (2021-05-26)

### Fixed

- Fixed `vagrant*` matching in the unix `get_ip()`

# [4.29.0](https://github.com/voxpupuli/beaker/compare/4.28.1...4.29.0) - 19-05-2021

### Added

- Ruby 3.0 support

# [4.28.1](https://github.com/voxpupuli/beaker/compare/4.28.0...4.28.1) - 03-10-2021

### Fixed

- Updated the ssh_preference example
- Fixed various spec tests
- Updated the `which` command to try `type -P` before falling back to `which`
  for systems that may not have `which` installed

# [4.28.0](https://github.com/voxpupuli/beaker/compare/4.27.1...4.28.0) - 12-21-2020

### Changed

- Arch Linux: Update box before installing packages ([#1688](https://github.com/voxpupuli/beaker/pull/1688))
- Move the entire workflow to Github Actions ([#1678](https://github.com/voxpupuli/beaker/pull/1678))
- Allow fakefs dependency in version >= 1 < 2 ([#1687](https://github.com/voxpupuli/beaker/pull/1687))

### Fixed

- Fix License text and SPDX code ([#1681](https://github.com/voxpupuli/beaker/pull/1678))

# [4.27.1](https://github.com/voxpupuli/beaker/compare/4.27.0...4.27.1) - 09-29-2020

### Changed

- Update net-scp requirement from "~> 1.2" to ">= 1.2, < 4.0"

### Fixed

- Handle systems going back in time after reboot
- Enhanced error handling during the reboot sequence
- Fixed time check logic during reboot
- Wrap paths around "" on pswindows

# [4.27.0](https://github.com/voxpupuli/beaker/compare/4.26.0...4.27.0) - 07-24-2020

### Changed

- Updated dependency versions and minimum Ruby version in gemspec to Ruby 2.4, which is the minimum
  version Beaker will run with.
- Added Travis unit testing and disabled Jenkins integrations in preparation for transferring the
  repo to Vox Pupuli


# [4.26.0](https://github.com/voxpupuli/beaker/compare/4.25.0...4.26.0)

### Changed

- Fixed deprecated SSH option handling for `verify_ssh_key` being passed into Net::SSH. #1655

### Removed

- Removed deprecated use of `paranoid` flag with Net::SSH. #1655

# [4.25.0](https://github.com/voxpupuli/beaker/compare/4.24.0...4.25.0)

### Added

- Execution of Beaker directly through ruby on localhost #1637 ([#1637](https://github.com/voxpupuli/beaker/pull/1637))

### Fixed

- Reliability improvements to the `Host#reboot` method ([#1656](https://github.com/voxpupuli/beaker/pull/1656)) ([#1659](https://github.com/voxpupuli/beaker/pull/1659))

# [4.24.0](https://github.com/voxpupuli/beaker/compare/4.23.0...4.24.0) - 2020-06-05

### Added

- Host method which ([#1651](https://github.com/voxpupuli/beaker/pull/1651))

### Fixed

- Fixed implementation for cat and file_exists? host methods for PSWindows ([#1654](https://github.com/voxpupuli/beaker/pull/1654))
- Fixed implementation for mkdir_p host method for PSWindows ([#1657](https://github.com/voxpupuli/beaker/pull/1657))

# [4.23.2](https://github.com/voxpupuli/beaker/compare/4.23.1...4.23.2)

### Fixed

- Fixed Beaker's behavior when the `strict_host_key_checking` option is
  provided in the SSH config and Net-SSH > 5 is specified. (#1652)

# [4.23.1](https://github.com/voxpupuli/beaker/compare/4.23.0...4.23.1)

### Changed/Removed

- Reversed the quoting changes on Unix from #1644 in favor of only quoting on Windows. (#1650)

# [4.23.0](https://github.com/voxpupuli/beaker/compare/4.22.1...4.23.0)

### Added

- Relaxed dependency on `net-ssh` to `>= 5` to support newer versions. (#1648)
- `cat` DSL method added. Works on both Unix and Windows hosts. (#1645)

### Changed

- The `mkdir_p` and `mv` commands now double quote their file arguments. (#1644) If you rely on file globbing in these methods or elsewhere, please open an issue on the BEAKER project.
- Change `reboot` method to use `who -b` for uptime detection (#1643)

### Fixed

- Use Base64 UTF-16LE encoding for commands (#1626)
- Fix `tmpdir` method for Powershell on Windows (#1645)

# [4.22.1](https://github.com/voxpupuli/beaker/compare/4.22.0...4.22.1)

### Fixed

- Removed single quotes around paths for file operation commands on `Host` https://github.com/voxpupuli/beaker/pull/1642

# [4.22.0](https://github.com/voxpupuli/beaker/compare/4.21.0...4.22.0) - 2020-05-08

### Added

- Host methods chmod and modified_at. ([#1638](https://github.com/voxpupuli/beaker/pull/1638))

### Removed

- Support for EL-5. ([#1639](https://github.com/voxpupuli/beaker/pull/1639)) ([#1640](https://github.com/voxpupuli/beaker/pull/1640))

# [4.21.0](https://github.com/voxpupuli/beaker/compare/4.20.0...4.21.0) - 2020-03-31

### Added

- Empty file `/etc/environment` while preparing ssh environment on Ubuntu 20.04 to keep the current behavior and consider all variables from `~/.ssh/environment`. ([#1635](https://github.com/voxpupuli/beaker/pull/1635))

# [4.20.0](https://github.com/voxpupuli/beaker/compare/4.19.0...4.20.0) - 2020-03-19

### Added

- Vagrant RSync/SSH settings will now be picked up if set via beaker-vagrant ([#1634](https://github.com/voxpupuli/beaker/pull/1634) and [beaker-vagrant#28](https://github.com/voxpupuli/beaker-vagrant/pull/28))

# [4.19.0](https://github.com/voxpupuli/beaker/compare/4.18.0...4.19.0) - 2020-03-13

### Added

- `apt-transport-https` package will now be installed on Debian-based systems as part of the prebuilt process. ([#1631](https://github.com/voxpupuli/beaker/pull/1631))
- Ubuntu 19.10 and 20.04 code name handling. ([#1632](https://github.com/voxpupuli/beaker/pull/1632))

### Changed

- The `wait_time`, `max_connection_tries`, and `uptime_retries` parameters have been added to `Host::Unix::Exec.reboot`. This allows for more fine-grained control over how the reboot is handled. ([#1625](https://github.com/voxpupuli/beaker/pull/1625))

### Fixed

- In `hosts.yml`, `packaging_platform` will now default to `platform` if unspecified. This fixed a bug where beaker would fail unless you specified both values in your config, even if both values were identical. ([#1628](https://github.com/voxpupuli/beaker/pull/1628))
- `version_is_less` will now correctly handle builds and RCs when used in version numbers. ([#1630](https://github.com/voxpupuli/beaker/pull/1630))

### Security
- Update `rake` to `~> 12.0`, which currently resolves to `12.3.3` to remediate [CVE-2020-8130](https://nvd.nist.gov/vuln/detail/CVE-2020-8130)

# [4.18.0](https://github.com/voxpupuli/beaker/compare/4.17.0...4.18.0) - 2020-02-26
### Changed
- Thor dependency bumped to >=1.0.1 <2.0

# [4.17.0](https://github.com/voxpupuli/beaker/compare/4.16.0...4.17.0) - 2020-02-20

### Added

- Windows support in `host_helpers` ([#1622](https://github.com/voxpupuli/beaker/pull/1622))
- EL 8 support ([#1623](https://github.com/voxpupuli/beaker/pull/1623))

# [4.16.0](https://github.com/voxpupuli/beaker/compare/4.15.0...4.16.0) - 2020-02-05

### Added

- release section to README ([#1618](https://github.com/voxpupuli/beaker/pull/1618))
- false return if `link_exists?` raises an error ([#1613](https://github.com/voxpupuli/beaker/pull/1613))

### Fixed

- `host.reboot` uses `uptime` rather than `ping` to check host status ([#1619](https://github.com/voxpupuli/beaker/pull/1619))

# [4.15.0](https://github.com/voxpupuli/beaker/compare/4.14.1...4.15.0) - 2020-01-30

### Added

- macOS 10.15 Catalina support (BKR-1621)

# [4.14.1](https://github.com/voxpupuli/beaker/compare/4.14.0...4.14.1) - 2019-11-18

### Fixed

- `fips_mode?` detection (#1607)

# [4.14.0](https://github.com/voxpupuli/beaker/compare/4.13.1...4.14.0) - 2019-11-12

### Added

- Pre-built steps output stacktraces when aborted (QENG-7466)

# [4.13.1](https://github.com/voxpupuli/beaker/compare/4.13.0...4.13.1) - 2019-10-07

### Fixed

- Use correct platform variant for FIPS repo configs download (BKR-1616)

# [4.13.0](https://github.com/voxpupuli/beaker/compare/4.12.0...4.13.0) - 2019-09-16

### Added

- Host `enable_remote_rsyslog` method (QENG-7466)

# [4.12.0](https://github.com/voxpupuli/beaker/compare/4.11.1...4.12.0) - 2019-08-14

### Added

- redhatfips as a recognized platform (PE-27037)

# [4.11.1](https://github.com/voxpupuli/beaker/compare/4.11.0...4.11.1) - 2019-08-13

### Changed

- `host.down?`'s wait from a fibonacci to a constant wait (BKR-1595)

# [4.11.0](https://github.com/voxpupuli/beaker/compare/4.10.0...4.11.0) - 2019-07-22

### Added

- FIPS detection host method (BKR-1604)
- PassTest exception catching for standard reporting

# [4.10.0](https://github.com/voxpupuli/beaker/compare/4.9.0...4.10.0) - 2019-07-01

### Added

- Down & Up Checking to Host#reboot (BKR-1595)

# [4.9.0](https://github.com/voxpupuli/beaker/compare/4.8.0...4.9.0) - 2019-06-19

### Changed

- SSH Connection failure backoff shortened (BKR-1599)

# [4.8.0](https://github.com/voxpupuli/beaker/compare/4.7.0...4.8.0) - 2019-04-17

### Added

- Support for Fedora >= 30 (BKR-1589)
- Codenames for Ubuntu 18.10, 19.04, and 19.10

### Changed

- Remove "repos-pe" prefix for repo filenames

# [4.7.0](https://github.com/voxpupuli/beaker/compare/4.6.0...4.7.0) - 2019-04-17

### Added

- Provide for OpenSSL 1.1.x+ support
- enable Solaris10Sparc pkgutil SSL CA2 (IMAGES-844)

### Changed

- update pry-byebug dependency 3.4.2->3.6 (BKR-1568)
- disabling hostkey checks for cisco hosts (QENG-7108)
- Change behavior of ruby versioning to accept job-parameter RUBY\_VER
- Change subcommand pre-suite to install ruby 2.3.1

# [4.6.0](https://github.com/voxpupuli/beaker/compare/4.5.0...4.6.0) - 2019.03.07

### Added

- Codename for Debian 10 'Buster'

# [4.5.0](https://github.com/voxpupuli/beaker/compare/4.4.0...4.5.0) - 2019.01.23

### Changed

- Do not mirror profile.d on Debian (BKR-1559)

# [4.4.0](https://github.com/voxpupuli/beaker/compare/4.3.0...4.4.0) - 2019.01.09

### Added

- Return root considerations for appending on nexus devices (BKR-1562)
- Permit user environment on osx-10.14 (BKR-1534)
- Add host helpers for working with files (BKR-1560)

### Changed

- Replace ntpdate with crony on RHEL-8 (BKR-1555)

# [4.3.0](https://github.com/voxpupuli/beaker/compare/4.2.0...4.3.0) - 2018.12.12

### Added

- Use zypper to install RPM packages on SLES (PA-2336)
- Add only-fails capability to beaker (BKR-1523)

# [4.2.0](https://github.com/voxpupuli/beaker/compare/4.1.0...4.2.0) - 2018.11.28

### Added

- `BEAKER_HYPERVISOR` environment variable to choose the beaker-hostgenerator hypervisor

### Changed

- Handling of vsh appended commands for cisco_nexus (BKR-1556)
- Acceptance tests: Add backoffs to other create_remote_file test

### Fixed

- Don't always start a new container with docker (can be reused between invocations of the provision and exec beaker subcommands) (BKR-1547)
- Recursively remove unpersisted subcommand options (BKR-1549)


# [4.1.0](https://github.com/voxpupuli/beaker/compare/4.0.0...4.1.0) - 2018.10.25

### Added

- `--preserve-state` flag will preserve a given host options hash across subcommand runs(BKR-1541)

### Changed

- Added additional tests for EL-like systems and added 'redhat' support where necessary
- Test if puppet module is installed in '/' and avoid stripping of path seperator

# [4.0.0](https://github.com/voxpupuli/beaker/compare/3.37.0...4.0.0) - 2018-08-06

### Fixed

- `host.rsync_to` throws `Beaker::Host::CommandFailure` if rsync call fails (BKR-463)
- `host.rsync_to` throws `Beaker::Host::CommandFailure` if rsync does not exist on remote system (BKR-462)
- `host.rsync_to` now check through configured SSH keys to use the first valid one
- Updated some `Beaker::Host` methods to always return a `Result` object

### Added

- Adds `Beaker::Host#chown`, `#chgrp`, and `#ls_ld` methods (BKR-1499)
- `#uninstall_package` host helper, to match `#install_package`
- `Host.uninstall_package` for FreeBSD
- Now easily check a command's exit status by calling `Result.success?()` for a simple, truthy result. No need to validate the exit code manually.

### Changed

- `#set_env` no longer calls `#configure_type_defaults_on`
- `beaker-puppet` DSL Extension Library has been formally split into a standard DSL Extension Library and removed as a dependency from Beaker. Please see our [upgrade guidelines](docs/how_to/upgrade_from_3_to_4.md).
- Beaker's Hypervisor Libraries have been removed as dependencies. Please see our [upgrade guidelines](docs/how_to/upgrade_from_3_to_4.md).

### Removed

- `PEDefaults` has been moved to `beaker-pe`

# [3.37.0](https://github.com/voxpupuli/beaker/compare/3.36.0...3.37.0) - 2018-07-11

### Fixed

- Exit early on --help/--version/--parse-only arguments instead of partial dry-run

### Added

- `Beaker::Shared::FogCredentials.get_fog_credentials()` to parse .fog credential files

### Changed

- `beaker-pe` is no longer automagically included. See [the upgrade guide](/docs/how_to/upgrade_from_3_to_4.md}) for more info
- `beaker-puppet` is no longer required as a dependency

# [3.36.0](https://github.com/voxpupuli/beaker/compare/3.35.0...3.36.0) - 2018-06-18

### Fixed

- Raise `ArgumentError` when passing `role = nil` to `only_host_with_role()` or `find_at_most_one_host_with_role()`
- Use `install_package_with_rpm` in `add_el_extras`

### Added

- Installation instructions for contributors
- Markdown formatting guidelines for `docs/`
- Glossary for project jargon in [`docs/concepts/glossary.md`](docs/concepts/glossary.md)
- Use AIX 6.1 packages everywhere for puppet6

# [3.35.0](https://github.com/voxpupuli/beaker/compare/3.34.0...3.35.0) - 2018-05-16

### Fixed

- Report accurate location of generated smoke test
- Accept comma-separated tests for exec subcommand

### Added

- Added optional ability to use ERB in nodeset YAML files

# [3.34.0](https://github.com/voxpupuli/beaker/compare/3.33.0...3.34.0) - 2018-03-26

### Fixed

- Recursively glob the tests directory

### Added

- Codename for Ubuntu 18.04 'Bionic'

# [3.33.0](https://github.com/voxpupuli/beaker/compare/3.32.0...3.33.0) - 2018-03-07

### Changed

- Use relative paths for beaker exec

# [3.32.0](https://github.com/voxpupuli/beaker/compare/3.31.0...3.32.0) - 2018-02-22

### Changed

- Fully qualify sles ssh restart cmd
- Deprecated deploy_package_repo methods
- Configuration of host type in host_prebuilt_steps

### Added

- Added missing beaker options for subcommand passthorugh

# [3.31.0](https://github.com/voxpupuli/beaker/compare/3.30.0...3.31.0) - 2018-01-22

### Changed

- Clean up ssh paranoid setting deprecation warnings

### Added

- Add macOS 10.13 support

# [3.30.0](https://github.com/voxpupuli/beaker/compare/3.29.0...3.30.0) - 2018-01-10

### Changed

- Use `host.hostname` when combining options host_hash with host instance options

### Removed

- `amazon` as a platform value

### Added

- Load project options from .beaker.yml

# [3.29.0](https://github.com/voxpupuli/beaker/compare/3.28.0...3.29.0) - 2017-11-16

### Added

- Adding default to read fog credentials

# [3.28.0](https://github.com/voxpupuli/beaker/compare/3.27.0...3.28.0) - 2017-11-01

### Fixed

- corruption of `opts[:ignore]` when using `rsync`

# [3.27.0](https://github.com/voxpupuli/beaker/compare/3.26.0...3.27.0) - 2017-10-19

### Added

- support amazon as a platform
- add codenames for MacOS 10.13 and Ubuntu Artful

# [3.26.0](https://github.com/voxpupuli/beaker/compare/3.25.0...3.26.0) - 2017-10-05

### Added

- concept of `manual_test` and `manual_step`

# [3.25.0](https://github.com/voxpupuli/beaker/compare/3.24.0...3.25.0) - 2017-09-26



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
