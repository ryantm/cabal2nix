# cabal2nix/doc/create-workspace.r

library(data.table)
library(rjson)
library(foreach)
library(doParallel)

### Set up the workspace.

cores <- detectCores()
options(cores=cores, mc.cores=cores)
cl <- makeForkCluster(cores)
registerDoParallel(cl)
setDefaultCluster(cl)

builds <- foreach (i=list.files(".", "*.json"), .combine="rbind") %dopar% {
    print(i)
    l <- fromJSON(file=i)
    pkgset <- names(l)
    data.table(pkgset, pkg=names(l[[pkgset]]), out=unlist(l[[pkgset]]))
}
setkey(builds, pkgset, pkg)

t <- foreach (out=unique(builds$out), .combine="rbind") %dopar% {
    size=system(paste("( du -sb", out, "| cut -f1 ) 2>/dev/null || true"), intern=TRUE)
    size <- if (identical(size, character(0))) "" else size
    data.table(out, size=as.integer(size))
}

builds <- merge(builds, t, by="out")

### Analyze the data.

# Total number of attributes in all package sets.
builds_total <- nrow(builds)

# Number of distict builds (output paths).
builds_unique <- length(unique(builds$out))

# Average output path size.
avg_build_size <- mean(builds[pkg != "ghc", size], na.rm=T)
sd_build_size <- sd(builds[pkg != "ghc", size], na.rm=T)
summary(builds[pkg != "ghc", size/1e6])

# Biggest builds.
biggest_builds <- head(builds[!is.na(size),list(size=mean(size)),by=pkg][order(size, decreasing=T)], n=20)
biggest_builds$size <- round(biggest_builds$size / 1e6, 1)

# Number of builds, distinguished by package set.
builds_by_pkgset <- builds[,list(attributes=length(pkg)), by=pkgset][order(pkgset)]