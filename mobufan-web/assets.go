package main

import "embed"

// webFS 内嵌前端静态资源（打包进单一二进制）。
//
//go:embed web/*
var webFS embed.FS
