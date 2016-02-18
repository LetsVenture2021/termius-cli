#!/usr/bin/env bats
load test_helper

setup() {
    clean_storage || true
    private_key_content='private_key content'
    private_key_path=key1
    echo -n $private_key_content > $private_key_path

    second_key_content='second_key content'
    second_key_path=key2
    echo -n $second_key_content > $second_key_path
}

teardown() {
    rm $private_key_path
    rm $second_key_path
}

@test "key help by arg" {
    run serverauditor key --help
    [ "$status" -eq 0 ]
}

@test "key help command" {
    run serverauditor help key
    [ "$status" -eq 0 ]
}

@test "Add general key" {
    run serverauditor key -L test -i $private_key_path
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 1 ]
    [ $(diff ~/.serverauditor/ssh_keys/test $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test | awk '{print $1}')" = '-rw-------' ]
    ssh_key=${lines[1]}
    [ "$(get_model_field 'sshkeycrypt_set' $ssh_key 'label')" = '"test"' ]
    [ "$(get_model_field 'sshkeycrypt_set' $ssh_key 'private_key')" = "\"$private_key_content\"" ]
    [ $(get_model_field 'sshkeycrypt_set' $ssh_key 'ssh_key') = 'null' ]
}

@test "Add many keys" {
    run serverauditor key -L test_1 -i $private_key_path
    run serverauditor key -L test_2 -i $private_key_path
    run serverauditor key -L test_3 -i $private_key_path
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 3 ]
    [ $(diff ~/.serverauditor/ssh_keys/test_1 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_1 | awk '{print $1}')" = '-rw-------' ]
    [ $(diff ~/.serverauditor/ssh_keys/test_2 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_1 | awk '{print $1}')" = '-rw-------' ]
    [ $(diff ~/.serverauditor/ssh_keys/test_3 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_1 | awk '{print $1}')" = '-rw-------' ]
}

@test "Update key" {
    key=$(serverauditor key -L test -i $private_key_path)
    run serverauditor key -i $second_key_path $key
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 1 ]
    [ $(diff ~/.serverauditor/ssh_keys/key $second_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test | awk '{print $1}')" = '-rw-------' ]
    [ "$(get_model_field 'sshkeycrypt_set' $key 'label')" = '"test"' ]
    [ "$(get_model_field 'sshkeycrypt_set' $key 'private_key')" = "\"$second_key_content\"" ]
    [ $(get_model_field 'sshkeycrypt_set' $key 'ssh_key') = 'null' ]
}

@test "Update many keys" {
    key1=$(serverauditor key -L test_1 -i $private_key_path)
    key2=$(serverauditor key -L test_2 -i $private_key_path)
    key3=$(serverauditor key -L test_3 -i $private_key_path)
    run serverauditor key -i $private_key_path $key1 $key2 $key3
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 3 ]
    [ $(diff ~/.serverauditor/ssh_keys/test_1 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_1 | awk '{print $1}')" = '-rw-------' ]
    [ $(diff ~/.serverauditor/ssh_keys/test_2 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_2 | awk '{print $1}')" = '-rw-------' ]
    [ $(diff ~/.serverauditor/ssh_keys/test_3 $private_key_path) = ""]
    [ "$(ls -al ~/.serverauditor/ssh_keys/test_2 | awk '{print $1}')" = '-rw-------' ]
}

@test "Delete key" {
    key=$(serverauditor key -L test_1 -i $private_key_path)
    run serverauditor key --delete $key
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 0 ]
    ! [ -f ~/.serverauditor/ssh_keys/test_1 ]
}

@test "Delete many keys" {
    key1=$(serverauditor key -L test_1 -i $private_key_path)
    key2=$(serverauditor key -L test_2 -i $private_key_path)
    key3=$(serverauditor key -L test_3 -i $private_key_path)
    run serverauditor key --delete $key1 $key2 $key3
    [ "$status" -eq 0 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 0 ]
    ! [ -f ~/.serverauditor/ssh_keys/test_1 ]
    ! [ -f ~/.serverauditor/ssh_keys/test_2 ]
    ! [ -f ~/.serverauditor/ssh_keys/test_3 ]
}

@test "Not add key with same ids" {
    serverauditor key -L test -i $private_key_path
    run serverauditor key -L test -i $private_key_path
    [ "$status" -eq 1 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 1 ]
}

@test "Not update key with same ids" {
    key1=$(serverauditor key -L test_1 -i $private_key_path)
    key2=$(serverauditor key -L test_2 -i $private_key_path)
    run serverauditor key -L test_2 -i $private_key_path $key1
    [ "$status" -eq 1 ]
    [ $(get_models_set_length 'sshkeycrypt_set') -eq 2 ]
}
