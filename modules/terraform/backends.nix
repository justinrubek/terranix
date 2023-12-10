# manage backend configurations and terraform_remote_state configurations
{ config, lib, ... }:

with lib;

let

  cfg = config.backend;

  localSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = with types; str;
        description = ''
          path to the state file
        '';
      };
    };
  };

  s3Submodule = types.submodule {
    options = {
      bucket = mkOption {
        type = with types; str;
        description = ''
          bucket name
        '';
      };
      key = mkOption {
        type = with types; str;
        description = ''
          path to the state file in the bucket
        '';
      };
      region = mkOption {
        type = with types; str;
        description = ''
          region of the bucket
        '';
      };
    };
  };

  etcdSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = with types; str;
        description = ''
          The path where to store the state
        '';
      };
      endpoints = mkOption {
        # todo : type should be listOf str
        type = with types; str;
        description = ''
          A space-separated list of the etcd endpoints
        '';
      };
      username = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          the username
        '';
      };
      password = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          the password
        '';
      };
    };
  };

  httpSubmodule = types.submodule {
    options = {
      address = mkOption {
        type = with types; str;
        description = ''
          The address to use for state storage
        '';
      };
      update_method = mkOption {
        default = "POST";
        type = with types; str;
        description = ''
          The HTTP method to use for state updates
        '';
      };
      lock_address = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          The address to use for state locking
        '';
      };
      lock_method = mkOption {
        default = "LOCK";
        type = with types; str;
        description = ''
          The HTTP method to use to lock the state
        '';
      };
      unlock_address = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          The address to use to unlock the state
        '';
      };
      unlock_method = mkOption {
        default = "UNLOCK";
        type = with types; str;
        description = ''
          The HTTP method to use to unlock the state
        '';
      };
      username = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          The username for HTTP authentication
        '';
      };
      password = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          The password for HTTP authentication
        '';
      };
      skip_cert_verification = mkOption {
        default = false;
        type = with types; bool;
        description = ''
          Whether or not to skip TLS verification
        '';
      };
      retry_max = mkOption {
        default = 2;
        type = with types; int;
        description = ''
          The maximum number of retries to make
        '';
      };
      retry_wait_min = mkOption {
        default = 1;
        type = with types; int;
        description = ''
          The minimum wait time between retries in seconds
        '';
      };
      retry_wait_max = mkOption {
        default = 30;
        type = with types; int;
        description = ''
          The maximum wait time between retries in seconds
        '';
      };
    };
  };
in {
  options.backend.local = mkOption {
    default = null;
    type = with types; nullOr localSubmodule;
    description = ''
      local backend
      https://www.terraform.io/docs/backends/types/local.html
    '';
  };

  options.remote_state.local = mkOption {
    default = { };
    type = with types; attrsOf localSubmodule;
    description = ''
      local remote state
      https://www.terraform.io/docs/backends/types/local.html
    '';
  };

  options.backend.s3 = mkOption {
    default = null;
    type = with types; nullOr s3Submodule;
    description = ''
      s3 backend
      https://www.terraform.io/docs/backends/types/s3.html
    '';
  };

  options.remote_state.s3 = mkOption {
    default = { };
    type = with types; attrsOf s3Submodule;
    description = ''
      s3 remote state
      https://www.terraform.io/docs/backends/types/s3.html
    '';
  };

  options.backend.etcd = mkOption {
    default = null;
    type = with types; nullOr etcdSubmodule;
    description = ''
      etcd backend
      https://www.terraform.io/docs/backends/types/etcd.html
    '';
  };

  options.remote_state.etcd = mkOption {
    default = { };
    type = with types; attrsOf etcdSubmodule;
    description = ''
      etcd remote state
      https://www.terraform.io/docs/backends/types/etcd.html
    '';
  };

  options.backend.http = mkOption {
    default = null;
    type = with types; nullOr httpSubmodule;
    description = ''
      http backend
      https://www.terraform.io/docs/backends/types/http.html
    '';
  };

  options.remote_state.http = mkOption {
    default = { };
    type = with types; attrsOf httpSubmodule;
    description = ''
      http remote state
      https://www.terraform.io/docs/backends/types/http.html
    '';
  };

  config =
    let
      backends = [ "local" "s3" "etcd" "http" ];
      notNull = element: !(isNull element);

      backendConfigurations =
        let
          rule = backend:
            mkIf (config.backend."${backend}" != null) {
              terraform."backend"."${backend}" = config.backend."${backend}";
            };

          backendConfigs = map (backend: config.backend."${backend}") backends;
        in
        mkAssert (length (filter notNull backendConfigs) < 2)
          "You defined multiple backends, stick to one!"
          (mkMerge (map rule backends));

      remoteConfigurations =
        let
          backendConfigs = map (backend: config.remote_state."${backend}") backends;
          allRemoteStates = flatten
            (map attrNames (filter (element: element != { }) backendConfigs));
          uniqueRemoteStates = unique allRemoteStates;

          remote = backend:
            mkIf (config.remote_state."${backend}" != { }) {
              data."terraform_remote_state" = mapAttrs
                (name: value: {
                  config = value;
                  backend = "${backend}";
                })
                config.remote_state."${backend}";
            };
        in
        mkAssert (length allRemoteStates == length uniqueRemoteStates)
          "You defined multiple terraform_states with the same name!"
          (mkMerge (map remote backends));
    in
    mkMerge [ backendConfigurations remoteConfigurations ];

}
