"mtree helpers"

BSDTAR_TOOLCHAIN = "@aspect_bazel_lib//lib:tar_toolchain_type"

def _mtree_line(file, type, content = None, uid = "0", gid = "0", time = "1672560000", mode = "0755"):
    spec = [
        file,
        "uid=" + uid,
        "gid=" + gid,
        "time=" + time,
        "mode=" + mode,
        "type=" + type,
    ]
    if content:
        spec.append("content=" + content)
    return " ".join(spec)

def _add_file_with_parents(path, file):
    lines = []
    segments = path.split("/")
    for i in range(1, len(segments)):
        parent = "/".join(segments[:i])
        if parent == "":
            continue
        lines.append(_mtree_line(parent.lstrip("/"), "dir"))

    lines.append(_mtree_line(path.lstrip("/"), "file", content = file.path))
    return lines

def _build_tar(ctx, mtree, output, inputs, compression = "gzip", mnemonic = "Tar"):
    bsdtar = ctx.toolchains[BSDTAR_TOOLCHAIN]

    mtree_out = ctx.actions.declare_file(ctx.label.name + ".spec")
    ctx.actions.write(mtree_out, content = mtree)

    inputs = inputs[:]
    inputs.append(mtree_out)

    args = ctx.actions.args()
    args.add("--create")
    args.add(compression, format = "--%s")
    args.add("--file", output)
    args.add(mtree_out, format = "@%s")

    ctx.actions.run(
        executable = bsdtar.tarinfo.binary,
        inputs = inputs,
        outputs = [output],
        tools = bsdtar.default.files,
        arguments = [args],
        mnemonic = mnemonic,
    )

def _create_mtree(ctx):
    content = ctx.actions.args()
    content.set_param_file_format("multiline")
    content.add("#mtree")
    return struct(
        line = lambda **kwargs: content.add(_mtree_line(**kwargs)),
        add_file_with_parents = lambda *args, **kwargs: content.add_all(_add_file_with_parents(*args), uniquify = kwargs.pop("uniqify", True)),
        build = lambda **kwargs: _build_tar(ctx, content, **kwargs),
    )

tar_lib = struct(
    create_mtree = _create_mtree,
    line = _mtree_line,
    add_file_with_parents = _add_file_with_parents,
    TOOLCHAIN_TYPE = BSDTAR_TOOLCHAIN,
)
