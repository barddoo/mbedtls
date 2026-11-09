const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mbedtls_dep = b.dependency("mbedtls", .{});
    const tf_psa_dep = b.dependency("tf_psa_crypto", .{});

    const threading = b.option(bool, "threading", "Enable thread safety") orelse false;

    const mbedtls = b.addLibrary(.{
        .name = "mbedtls",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Include paths: mbedtls public headers
    mbedtls.root_module.addIncludePath(mbedtls_dep.path("include"));
    // Include paths: tf-psa-crypto public headers (psa/, mbedtls/, tf-psa-crypto/)
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("include"));
    // Private headers needed to compile tf-psa-crypto sources
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("drivers/builtin/include"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("drivers/builtin/src"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("core"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("dispatch"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("drivers/pqcp/include"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("extras"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("platform"));
    mbedtls.root_module.addIncludePath(tf_psa_dep.path("utilities"));
    // Private headers for mbedtls library sources
    mbedtls.root_module.addIncludePath(mbedtls_dep.path("library"));
    // Generated driver wrapper headers (psa_crypto_driver_wrappers.h)
    mbedtls.root_module.addIncludePath(b.path("generated"));

    // mbedtls library sources (SSL/TLS, X.509, etc.)
    mbedtls.root_module.addCSourceFiles(.{
        .root = mbedtls_dep.path("library"),
        .files = mbedtls_srcs,
    });

    // tf-psa-crypto: PSA core
    mbedtls.root_module.addCSourceFiles(.{
        .root = tf_psa_dep.path("core"),
        .files = tf_psa_core_srcs,
    });

    // tf-psa-crypto: builtin crypto drivers
    mbedtls.root_module.addCSourceFiles(.{
        .root = tf_psa_dep.path("drivers/builtin/src"),
        .files = tf_psa_builtin_srcs,
    });

    // tf-psa-crypto: platform utilities
    mbedtls.root_module.addCSourceFiles(.{
        .root = tf_psa_dep.path("platform"),
        .files = tf_psa_platform_srcs,
    });

    // tf-psa-crypto: shared utilities (ASN.1, base64, etc.)
    mbedtls.root_module.addCSourceFiles(.{
        .root = tf_psa_dep.path("utilities"),
        .files = tf_psa_utilities_srcs,
    });

    // tf-psa-crypto: extras (PK, MD, LMS, etc.)
    mbedtls.root_module.addCSourceFiles(.{
        .root = tf_psa_dep.path("extras"),
        .files = tf_psa_extras_srcs,
    });

    // Generated: PSA driver wrappers (non-static dispatch)
    mbedtls.root_module.addCSourceFile(.{
        .file = b.path("generated/psa_crypto_driver_wrappers_no_static.c"),
        .flags = &.{},
    });

    if (target.result.os.tag == .freebsd) {
        mbedtls.root_module.addCMacro("__BSD_VISIBLE", "1");
    }
    if (threading) {
        mbedtls.root_module.addCMacro("MBEDTLS_THREADING_C", "");
        mbedtls.root_module.addCMacro("MBEDTLS_THREADING_PTHREAD", "");
    }

    // Install public headers from both packages
    mbedtls.installHeadersDirectory(mbedtls_dep.path("include/mbedtls"), "mbedtls", .{});
    mbedtls.installHeadersDirectory(tf_psa_dep.path("include/mbedtls"), "mbedtls", .{});
    mbedtls.installHeadersDirectory(tf_psa_dep.path("include/psa"), "psa", .{});
    mbedtls.installHeadersDirectory(tf_psa_dep.path("include/tf-psa-crypto"), "tf-psa-crypto", .{});
    b.installArtifact(mbedtls);

    if (target.result.os.tag == .windows) {
        mbedtls.root_module.linkSystemLibrary("bcrypt", .{});
    }

    const selftest = b.addExecutable(.{
        .name = "selftest",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    selftest.root_module.addCMacro("MBEDTLS_SELF_TEST", "");
    selftest.root_module.addIncludePath(tf_psa_dep.path("drivers/builtin/include"));
    selftest.root_module.addCSourceFile(.{
        .file = mbedtls_dep.path("programs/test/selftest.c"),
        .flags = &.{},
    });
    selftest.root_module.linkLibrary(mbedtls);
    b.getInstallStep().dependOn(&selftest.step);

    const selftest_run = b.addRunArtifact(selftest);
    const test_step = b.step("test", "Run Tests");
    test_step.dependOn(&selftest_run.step);
}

const mbedtls_srcs: []const []const u8 = &.{
    "debug.c",
    "mps_reader.c",
    "mps_trace.c",
    "net_sockets.c",
    "pkcs7.c",
    "ssl_cache.c",
    "ssl_ciphersuites.c",
    "ssl_client.c",
    "ssl_cookie.c",
    "ssl_msg.c",
    "ssl_ticket.c",
    "ssl_tls.c",
    "ssl_tls12_client.c",
    "ssl_tls12_server.c",
    "ssl_tls13_client.c",
    "ssl_tls13_generic.c",
    "ssl_tls13_keys.c",
    "ssl_tls13_server.c",
    "timing.c",
    "version.c",
    "x509_create.c",
    "x509_crl.c",
    "x509_crt.c",
    "x509_csr.c",
    "x509_oid.c",
    "x509.c",
    "x509write_crt.c",
    "x509write_csr.c",
    "x509write.c",
};

const tf_psa_core_srcs: []const []const u8 = &.{
    "psa_crypto.c",
    "psa_crypto_client.c",
    "psa_crypto_random.c",
    "psa_crypto_slot_management.c",
    "psa_crypto_storage.c",
    "psa_its_file.c",
    "psa_util.c",
    "tf_psa_crypto_version.c",
};

const tf_psa_builtin_srcs: []const []const u8 = &.{
    "aes.c",
    "aesce.c",
    "aesni.c",
    "aria.c",
    "bignum_core.c",
    "bignum_mod_raw.c",
    "bignum_mod.c",
    "bignum.c",
    "block_cipher.c",
    "camellia.c",
    "ccm.c",
    "chacha20.c",
    "chacha20_neon.c",
    "chachapoly.c",
    "cipher_wrap.c",
    "cipher.c",
    "cmac.c",
    "ctr_drbg.c",
    "ecdsa.c",
    "ecjpake.c",
    "ecp_curves.c",
    "ecp.c",
    "entropy_poll.c",
    "entropy.c",
    "gcm.c",
    "hmac_drbg.c",
    "md5.c",
    "poly1305.c",
    "psa_crypto_aead.c",
    "psa_crypto_cipher.c",
    "psa_crypto_ecp.c",
    "psa_crypto_ffdh.c",
    "psa_crypto_hash.c",
    "psa_crypto_mac.c",
    "psa_crypto_pake.c",
    "psa_crypto_rsa.c",
    "psa_crypto_xof.c",
    "psa_util_internal.c",
    "ripemd160.c",
    "rsa_alt_helpers.c",
    "rsa.c",
    "sha1.c",
    "sha256.c",
    "sha3.c",
    "sha512.c",
};

const tf_psa_platform_srcs: []const []const u8 = &.{
    "memory_buffer_alloc.c",
    "platform_util.c",
    "platform.c",
    "threading.c",
};

const tf_psa_utilities_srcs: []const []const u8 = &.{
    "asn1parse.c",
    "asn1write.c",
    "base64.c",
    "constant_time.c",
    "oid.c",
    "pem.c",
    "pkcs5.c",
};

const tf_psa_extras_srcs: []const []const u8 = &.{
    "lmots.c",
    "lms.c",
    "md.c",
    "nist_kw.c",
    "pk_ecc.c",
    "pk_rsa.c",
    "pk_wrap.c",
    "pk.c",
    "pkparse.c",
    "pkwrite.c",
};
