##############################
#  The MIT License (MIT)     #
#                            #
#  Copyright (c) 2014 gsick  #
##############################
#!/bin/sh
set -e

TEST_NGINX_OPENAM_URI="http://....:.../openam" \
TEST_NGINX_OPENAM_USER="..." \
TEST_NGINX_OPENAM_PWD="..." \
TEST_NGINX_OPENAM_USER_TEST="must be different than the first user" \
TEST_NGINX_OPENAM_PWD_TEST="..." \
TEST_NGINX_OPENAM_REALM="realm of the user_test e.g. /test" \
TEST_NGINX_OPENAM_URL_AUTHORIZE="http://..." \
TEST_NGINX_OPENAM_URL_UNAUTHORIZE="http://..." \
prove ../t/*.t
