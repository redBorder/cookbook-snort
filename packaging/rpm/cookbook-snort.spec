Name: cookbook-snort
Version: %{__version}
Release: %{__release}%{?dist}.1
BuildArch: noarch
Summary: cookbook to deploy snort in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-example
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/snort
cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/snort
chmod -R 0755 %{buildroot}/var/chef/cookbooks/snort
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/snort/README.md

%pre
if [ -d /var/chef/cookbooks/snort ]; then
    rm -rf /var/chef/cookbooks/snort
fi

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload snort'
  ;;
esac

%postun
# Deletes directory when uninstall the package
if [ "$1" = 0 ] && [ -d /var/chef/cookbooks/snort ]; then
  rm -rf /var/chef/cookbooks/snort
fi

%files
%defattr(0755,root,root)
/var/chef/cookbooks/snort
%defattr(0644,root,root)
/var/chef/cookbooks/snort/README.md


%doc

%changelog
* Thu Oct 10 2024 Miguel Negrón <manegron@redborder.com>
- Add pre and postun

* Fri Jan 07 2022 David Vanhoucke <dvanhoucke@redborder.com>
- change register to consul

* Wed Oct 06 2021 Javier Rodriguez <javiercrg@redborder.com>
- Added creation template directory

* Mon Jan 16 2017 Alberto Rodríguez <arodriguez@redborder.com>
- first spec version
