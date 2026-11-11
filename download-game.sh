#!/bin/sh
# 从 ContentDB 下载设置里选中的游戏，解压到数据卷的 games/ 下；已存在就跳过（幂等）。
# 一次性服务：每次创建容器都重跑（安装、升级、重建），装过的游戏不重复下载。
set -eu

GAME="${WONTON_SETTING_GAME:?云吞没把 WONTON_SETTING_GAME 传进来}"
DATA="/var/lib/minetest"
# gameid（= 解压出来的目录名，引擎按目录名认游戏）→ ContentDB 的包。
# 包名和“维护中”状态 2026-11-12 在 content.luanti.org 核对过。
case "$GAME" in
	mineclonia) PKG=ryvnf/mineclonia ;;
	mineclone2) PKG=Wuzzy/mineclone2 ;;
	minetest_game) PKG=Luanti/minetest_game ;;
	*)
		echo "settings 的 game 值不在下载脚本名单里：$GAME" >&2
		exit 1
		;;
esac

DEST="$DATA/games/$GAME"
if [ -d "$DEST" ]; then
	echo "游戏已存在，跳过下载：$DEST"
	exit 0
fi

mkdir -p "$DATA/games"

# 最新 release 的 id 在包接口的 "release" 字段里，下载地址按 release id 拼。
RELEASE="$(curl -fsSL "https://content.luanti.org/api/packages/$PKG/" |
	grep -o '"release":[0-9]*' | grep -o '[0-9]*' || true)"
if [ -z "$RELEASE" ]; then
	echo "取不到 $PKG 的最新版本（content.luanti.org 的包接口没返回 release 字段）" >&2
	exit 1
fi

echo "下载 $PKG release $RELEASE"
curl -fsSL --retry 3 --connect-timeout 20 -o /tmp/game.zip \
	"https://content.luanti.org/packages/$PKG/releases/$RELEASE/download/"

# 先解到临时目录，确认包里是单个 games/<gameid> 目录再就位；半途失败不留半个游戏目录。
TMP="$DATA/games/.downloading-$GAME"
rm -rf "$TMP"
mkdir -p "$TMP"
unzip -q /tmp/game.zip -d "$TMP"
rm -f /tmp/game.zip
if [ ! -d "$TMP/$GAME" ]; then
	rm -rf "$TMP"
	echo "下载包里没有 $GAME/ 目录（ContentDB 的目录结构和预期不符）" >&2
	exit 1
fi
mv "$TMP/$GAME" "$DEST"
rmdir "$TMP"
echo "游戏就绪：$DEST"
