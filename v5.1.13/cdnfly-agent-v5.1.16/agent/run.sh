export FLASK_APP="/opt/cdnfly/agent/route.py"
export FLASK_DEBUG=1
/opt/venv/bin/flask run --cert=/opt/cdnfly/agent/conf/default.cert --key=/opt/cdnfly/agent/conf/default.key  -h 0.0.0.0 -p 5000 --with-threads 

