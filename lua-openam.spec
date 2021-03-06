%define luaver 5.1
%define luadatadir %{_datadir}/lua/%{luaver}

Name:       lua-openam
Version:    0.0.4
Release:    1%{?dist}
Summary:    Lua OpenAM client driver for the nginx HttpLuaModule

Group:      Development/Libraries
License:    MIT
URL:        https://github.com/gsick/lua-openam
Source0:    https://github.com/gsick/lua-openam/archive/%{version}.tar.gz
BuildRoot:  %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:   lua >= %{luaver}

%description
The Lua OpenAM module provides basic functions for OpenAM RESTful API. It features:
- Authentication / Logout
- Token validation
- Authorization
- Read identity
- Dependencies on lua-cjson, lua-resty-http, luautf8

%prep
%setup -q


%build


%install
rm -rf "$RPM_BUILD_ROOT"
make install DESTDIR="$RPM_BUILD_ROOT" LUA_MODULE_DIR="%{lualibdir}"


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
%doc LICENSE README.md
%dir /%{lualibdir}/
%dir /%{lualibdir}/openam/
/%{lualibdir}/openam/openam.lua

%changelog
* Tue Mar 18 2014 Gamaliel Sick <@> - 0.0.4-1
- Update package

* Tue Mar 18 2014 Gamaliel Sick <@> - 0.0.3-1
- Update package

* Mon Mar 17 2014 Gamaliel Sick <@> - 0.0.2-1
- Update package

* Mon Mar 10 2014 Gamaliel Sick <@> - 0.0.1-1
- Initial package
