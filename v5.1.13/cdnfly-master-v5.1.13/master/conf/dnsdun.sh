#!/bin/bash

#
#Dnsdun_uid="1234"
#
#Dnsdun_api_key="SCudJdFj7MQCzbXS"

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dnsdun_add() {
    fulldomain=$1
    txtvalue=$2

    Dnsdun_uid="${Dnsdun_uid:-$(_readaccountconf_mutable Dnsdun_uid)}"
    Dnsdun_api_key="${Dnsdun_api_key:-$(_readaccountconf_mutable Dnsdun_api_key)}"

    if [ -z "$Dnsdun_uid" ] || [ -z "$Dnsdun_api_key" ]; then
        Dnsdun_uid=""
        Dnsdun_api_key=""
        _err "You didn't specify a dnsdun api key and uid yet."
        return 1
    fi

    _saveaccountconf_mutable Dnsdun_uid "$Dnsdun_uid"
    _saveaccountconf_mutable Dnsdun_api_key "$Dnsdun_api_key"

    _debug "First detect the root zone"
    if ! _get_root "$fulldomain"; then
        _err "invalid domain"
        return 1
    fi

    _debug _sub_domain "$_sub_domain"
    _debug _domain "$_domain"

    _info "Check record exists"
    if _rest_req "https://api.dnsdun.com/?c=record&a=list" "domain="${_domain}"&keyword="${txtvalue}"&t=TXT"; then
        if ! _contains "$response" "\"record_total\":\"0\""; then
            _info "Record exists"
            return 0
        fi
    fi

    _info "Adding record"
    if _rest_req "https://api.dnsdun.com/?c=record&a=add" "domain="${_domain}"&sub_domain="${_sub_domain}"&record_type=TXT&record_line=默认&value="${txtvalue}"&ttl=120"; then
        if _contains "$response" "\"code\":1"; then
            _info "Added, OK"
            return 0
        else
            _err "Add txt record error."
            return 1
        fi
    fi
    _err "Add txt record error."
    return 1    

}  

#fulldomain txtvalue
dnsdun_rm() {
    fulldomain=$1
    txtvalue=$2

    Dnsdun_uid="${Dnsdun_uid:-$(_readaccountconf_mutable Dnsdun_uid)}"
    Dnsdun_api_key="${Dnsdun_api_key:-$(_readaccountconf_mutable Dnsdun_api_key)}"

    _debug "First detect the root zone"
    if ! _get_root "$fulldomain"; then
        _err "invalid domain"
        return 1
    fi

    _debug _sub_domain "$_sub_domain"
    _debug _domain "$_domain"

    _info "Check record exists"
    if _rest_req "https://api.dnsdun.com/?c=record&a=list" "domain="${_domain}"&keyword="${txtvalue}"&t=TXT"; then
        if _contains "$response" "\"record_total\":\"0\""; then
            _info "Record not exists"
            return 0
        fi
    fi

    record_id=$(echo "$response" |  _egrep_o "\"id\":\"[0-9]+\"" | _egrep_o "[0-9]+")

    _info "Removing record"
    if _rest_req "https://api.dnsdun.com/?c=record&a=del" "domain="${_domain}"&record_id="${record_id}; then
        if _contains "$response" "\"code\":1"; then
            _info "Del, OK"
            return 0
        else
            _err "Del record error."
            return 1
        fi
    fi
    _err "Del record error."
    return 1   

}


####################  Private functions below ##################################
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
# _domain_id=sdjkglgdfewsdfg
_get_root() {
  domain=$1
  i=1
  p=1

  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)
    _debug h "$h"
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    if ! _rest_req "https://api.dnsdun.com/?c=domain&a=getList" "keyword="$h"&offset=0&length=10&group_id=null"; then
        return 1
    fi

    _debug "response:$response"

    if _contains "$response" "\"domain_total\":\"1\""; then
        _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
        _domain=$h
        return 0
    fi
    p=$i
    i=$(_math "$i" + 1)
  done

}

_rest_req() {
    url=$1
    data=$2

    data=$data"&format=json&api_key="$Dnsdun_api_key"&uid="$Dnsdun_uid

    export _H1="Content-Type: application/x-www-form-urlencoded"
    response="$(_post "$data" "$url")"
    if [ "$?" != "0" ]; then
        _err "error $url"
        return 1
    fi

    return 0
}



