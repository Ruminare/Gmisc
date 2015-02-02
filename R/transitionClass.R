#' A reference class for generating transition plots
#' 
#' This class simplifies the creating of transition plots. It also 
#' allows for advanced multi-column transitions. 
#'
#' @field transitions This is a >= 3 dimensional array with the transitions. Should not be direcly accessed.
#' @field box_width The box width
#' @field box_txt The texts of each box
#' @field box_label Box labels on top/bottom of the boxes
#' @field box_label_pos Either "top"/"bottom"
#' @field box_label_cex The size of the box labels
#' @field vertical_space The space between 
#' @field fill_clr The fill color
#' @field txt_clr The text color within the boxes
#' @field box_cex The fontsize multiplier for the text within the boxes
#' @field title The plot title if any
#' @field title_cex The fontsize multiplier for the title
#' @field mar The margins for the plot. 
#' @field lwd_prop_total If the line with should be proportional to the 
#'  maximum width within the full matrix or just proportional to the
#'  each transition set.
#' @field data Internal storage variable. Should not be accessed directly.
#' 
#' @import magrittr
#' @importFrom methods setRefClass
#' @import abind
#' @export
Transition <-
  setRefClass(
    "Transition",
    fields = list(
      data = "list",
      transitions = function(value){
        if (missing(value)){
          return(data$transitions)
        }

        if (is.null(attr(value, "transition")))
          stop("You are only allowed to use new()/addTransitions() method for setting the transitions")
        if (!is.numeric(value))
          stop("You have provided a non-numeric matrix: '", typeof(value), "'' of class '", class(value), "'")
        if (!length(dim(value)) %in% 3:4)
          stop("The dimensions of the transition matrix has to be between 2 and 3.",
               " This means that the stored transitions should have an additional dimension",
               " in order to allow for multiple transitions.")
        if (ncol(value) != nrow(value))
          stop("The transtion matrix has to be of equal number of rows and columns.",
               " If a certain factor level is not present after the transition that level's",
               " column should sum up to 0. You have provided '", nrow(value), "' rows",
               " and '", ncol(value), "' columns.")
        data$transitions <<- value
      },
      box_width = function(value){
        if (missing(value))
          return(data$box_width)

        if (!inherits(value, "unit") &&
              value > 1 && value < 0)
          stop("The box width must be grid::unit or a double between 0 and 1")
        if (inherits(value, "unit")){
          raw_width <- convertUnit(value, unitTo = "npc", axisFrom = "x", axisTo = "x", valueOnly = TRUE)
        }else{
          raw_width <- value
          value <- unit(value, "npc")
        }

        if (raw_width * .self$noCols() * 1.1 > 1)
          stop("Your box_width leaves less than 10% for arrows assuming you have the current plot size")

        data$box_width <<- value
      },
      box_txt = function(value){
        if (missing(value))
          return(data$box_txt)

        if (NROW(value) != .self$noRows())
          stop("Your labels should match the number of rows within the transition matrix")
        if (is.matrix(value) &&
              ncol(value) > 1){
          if (ncol(value) != .self$noCols())
            stop("Your labels need to match the number of columns")
        }else{
          value <- matrix(value,
                          nrow = .self$noRows(),
                          ncol = .self$noCols())
        }
        data$box_txt <<- value
      },
      box_label = function(value){
        if (missing(value))
          return(data$box_label)

        if (length(value) != .self$noCols())
          stop("You have provided '", length(value), "' box labels",
               " while there are '", .self$noCols(), "' columns that require a label.")
        data$box_label <<- value
      },
      box_label_pos = function(value){
        if (missing(value))
          return(data$box_label_pos)

        value <- tolower(value)
        if (value %in% c("top","bottom"))
          stop("Only top/bottom are allowed for the box_label_pos")

        data$box_label_pos <<- value
      },
      box_label_cex = function(value){
        if (missing(value)){
          if (!is.null(data$box_label_cex))
            return(data$box_label_cex)

          return(box_cex*1.2)
        }

        if (!is.numeric(value) && !is.null(value))
          stop("Only numeric cex values are accepted")

        data$box_label_cex <<- value
      },
      vertical_space = function(value){
        if (missing(value))
          return(data$vertical_space)

        if (!inherits(value, "unit") &&
              value >= 1 && value < 0)
          stop("The box width must be grid::unit or a double at least 0 and below 1")
        if (inherits(value, "unit")){
          raw_space <- convertUnit(value, unitTo = "npc", axisFrom = "y", axisTo = "y", valueOnly = TRUE)
          if (raw_space >= 1)
            stop("Using your current graph size the provided value is as large as the graph")
          if (raw_space < 0)
            stop("You cannot have empty space smaller than 0")
        }else{
          value <- unit(value, "npc")
        }

        data$vertical_space <<- value
      },
      fill_clr = function(value){
        if (missing(value))
          return(data$fill_clr)

        value <- prTcValidateAndPrepClr(value, transitions, .self)

        data$fill_clr <<- value
      },
      txt_clr = function(value){
        if (missing(value))
          return(data$txt_clr)

        value <- prTcValidateAndPrepClr(value, transitions, .self)

        data$txt_clr <<- value
      },
      box_cex = function(value){
        if (missing(value)){
          if (!is.null(data$box_cex))
            return(data$box_cex)
          if (is.null(data$box_txt))
            return(1)

          all_texts <- unlist(sapply(as.vector(box_txt), function(x) strsplit(x, "\n")[[1]], USE.NAMES = FALSE))
          longest_txt <- all_texts[which.max(sapply(all_texts, nchar))]
          base_width <- convertWidth(grobWidth(textGrob(label = longest_txt, gp = gpar(cex = 1))), unitTo = "npc", valueOnly = TRUE)
          width_cex <- convertWidth(box_width, unitTo = "npc", valueOnly = TRUE)*.8/base_width

          min_height <- Inf
          for (col in 1:.self$noCols()){
            proportions <- getYProps(col)
            proportions <- proportions[proportions > 0]
            min_height %<>%
              min(proportions)
          }
          max_txt_height <- min_height * .6
          base_height <- convertUnit(grobHeight(textGrob(label = "A", gp = gpar(cex = 1))),
                                     unitTo = "npc", axisFrom = "y", valueOnly = TRUE)
          height_cex <- max_txt_height/base_height

          return(max(.75, min(width_cex, height_cex)))
        }

        if (value < 0 && !is.null(value))
          stop("The cex is a multiplier of the font size and has to be at minimum 0")

        data$box_cex <<- value
      },
      title = function(value){
        if (missing(value))
          return(data$title)

        if (is.null(value) ||
              nchar(value) == 0){
          data$title <<- NULL
        }else{
          data$title <<- value
        }
      },
      title_cex = function(value){
        if (missing(value)){
          if (!is.null(data$title_cex))
            return(data$title_cex)

          return(box_label_cex*1.2)
        }

        if (!is.numeric(value))
          stop("Only numeric cex values are accepted")

        data$title_cex <<- value
      },
      mar = function(value){
        if (missing(value)){
          if (!is.null(data$mar))
            return(data$mar)
          if (is.null(data$mar))
            return(unit(rep(3, times=4), "mm"))
        }

        if (!is.unit(value))
          value <- unit(value, "npc")

        if (length(value) == 1){
          tmp <- value
          for (i in 1:3)
            tmp <- unit.c(tmp, value)
          value <- tmp
        }

        if (length(value) != 4)
          stop("There are 4 margins, you have supplied '", length(value), "'")

        data$mar <<- value
      },
      lwd_prop_total = function(value){
        if (missing(value)){
          if (!is.null(data$lwd_prop_total))
            return(data$lwd_prop_total)
          
          return(FALSE)
        }
        
        if (!is.logical(value))
          stop("The lwd_prop_total can either be TRUE or FALSE.",
               " While you have provided the value '", value, "'")
        
        data$lwd_prop_total <<- value
      }),
    methods = list(
      initialize = function(transitions, label, txt, fill_clr, txt_clr, ...){
        "Set up a Transition object. The \\code{transitions} should be a 2D or 3D matrix
        as defined in the \\code{$addTransitions} section and not as later internally stored."
        if (missing(transitions))
          stop("You must provide a transition matrix when creating a Transition object")

        if (is.character(transitions) &&
              all(transitions == "copy"))
          return(callSuper(...))

        .self$addTransitions(transitions, label, txt = txt, fill_clr = fill_clr, txt_clr = txt_clr)
        callSuper(...)
      },
      copy = function (shallow = FALSE)
      {
        "A custom \\code{$copy} function as the initialize requires a transitions argument"
        def <- .refClassDef
        value <- new(def, "copy")
        vEnv <- as.environment(value)
        selfEnv <- as.environment(.self)
        for (field in names(def@fieldClasses)) {
          if (shallow)
            assign(field, get(field, envir = selfEnv), envir = vEnv)
          else {
            current <- get(field, envir = selfEnv)
            if (is(current, "envRefClass"))
              current <- current$copy(FALSE)
            assign(field, current, envir = vEnv)
          }
        }
        value
      },
      addTransitions = function(mtrx, label, txt, fill_clr, txt_clr){
        "Add a transition matrix. The input has to be a numerical matrix between 2 and 3 dimensions.
        If you don't provide the txt field the box' text field will be deduced from the transition matrix'
        dimnames. The fill_clr and txt_clr are passed on to the \\code{addClr} function."

        if (length(transitions) > 0){
          if (!is.null(attr(mtrx, "transition"))){
            transitions <<- mtrx
            return()
          }else if(.self$noRows() !=
                     nrow(mtrx)){
            stop("The number of elements within the new matrix must be equal to the previous matrix.",
                 " You have provided '", nrow(mtrx), "' elements",
                 " while there are previously '", .self$noRows(), "' elements.")
          } else if(sum(.self$boxSizes("last") - rowSums(mtrx)) > .Machine$double.eps*nrow(mtrx)){
            stop("You have provided a transition matrix starting with the sizes ", prPasteVec(rowSums(mtrx)),
                 " while the previous transition matrix resulted in sizes ", prPasteVec(.self$boxSizes("last")), ".",
                 " These two should be equal.")
          }

          mtrx <- abind(transitions, mtrx, along = length(dim(mtrx)) + 1)

          raw_width <- convertUnit(box_width, unitTo = "npc", axisFrom = "x", axisTo = "x", valueOnly = TRUE)
          shrinkage <- (.self$noCols() * 2 - 1)/((.self$noCols() + 1) * 2 - 1)
          bw <- unit(raw_width * shrinkage, units = "npc")
        }else{
          mtrx <- abind(mtrx, along = length(dim(mtrx)) + 1)
          bw <- unit(1/4, units = "npc")
        }
        attr(mtrx, "transition") <- TRUE

        transitions <<- mtrx
        box_width <<- bw
        vertical_space <<- unit(.6/.self$noRows(), units = "npc")

        if (!missing(label)){
          if (.self$noCols() > 2){
            box_label <<- c(box_label, label)
          }else{
            box_label <<- label
          }
        }

        if (missing(txt)){
          if (all(sapply(dimnames(mtrx), is.null))){
            txt <- rep("", times = nrow(mtrx))
          }else if (sum(!sapply(dimnames(mtrx)[1:2], is.null)) == 1){
            txt <- dimnames(mtrx)[[which(!sapply(dimnames(mtrx)[1:2], is.null))]]
          }else if (.self$noCols() == 2){
            txt <- cbind(rownames(mtrx), colnames(mtrx))
          }else{
            txt <- colnames(mtrx)
          }
        }else if (NROW(txt) != NROW(mtrx)){
          stop("You must provide the same number of txt as rows in the transition matrix")
        }

        if (.self$noCols() > 2){
          box_txt <<- cbind(box_txt, txt)
        }else{
          box_txt <<- txt
        }

        .self$addClr(fill = fill_clr,
                     txt  = txt_clr)

        invisible(mtrx)
      },
      addClr = function(fill, txt){
        "Adds colors or extends existing one so that they match the transition matrix.
        The fill corresponds to the fill_clr and txt corresponds to the txt_clr. If
        the colors are missing and the transitions consist of only two columns the default
        colors will be used. If the matrix is being extended and these values are missing the
        values from the previous last column will be used for the default columns."
        matchClr <- function(add, org){
          if (.self$noCols() == 2){
            # If this is the initial value then simply use the default colors
            return(add)
          }

          # We need to handle the situation where a color is
          # added and the colors are already of the same dimension
          # as the transition matrix. This means that either we
          # switch entire matrix if the new colors have the correct
          # dimenension but otherwise we stick with the old colors
          if (all(dim(org) == .self$getDim())){
            if (missing(add))
              return(org)
            # If the add is equal in dimentions to the target
            # dimentions then the reasonable way to go is to substitute
            # all colors
            if (is.matrix(add) &&
                all(dim(add) == .self$getDims()))
              return(add)

            return(org)
          }


          if (missing(add)){
            last <- asub(org, idx = ncol(org), dims = 2)
          }else{
            no_clr_dims <- 1 + (length(.self$getDim()) == 3)
            if (length(add) == 1){
              last <- array(add, dim = c(.self$noRows(), no_clr_dims))
            }else if (length(add) == 2){
              if (no_clr_dims == 2){
                last <- cbind(rep(add[1], times = .self$noRows()),
                              rep(add[2], times = .self$noRows()))
              }else{
                last <- array(add, dim = c(.self$noRows(), no_clr_dims))
              }
            }else if (is.matrix(add)){
              last <- apply(add, 2, function(x) rep(x, length.out=.self$noRows()))
              # Select the last rows for the color
              if (ncol(last) > no_clr_dims){
                if (no_clr_dims == 1){
                  last <- last[,ncol(last)]
                }else{
                  last <- last[,(ncol(last) - 1):ncol(last)]
                }
              }
            }else{
              # Will map the colors according to rows
              last <- array(add, dim = c(.self$noRows(), no_clr_dims))
            }
          }
          return(abind(org, last, along = 2))
        }

        if (missing(fill) &&
              .self$noCols() == 2){
          # This is the color initialization
          if (length(.self$getDim()) == 3){
            fill <- c("#fdc086", "#386cb0")
          }else{
            fill <- c("darkgreen")
          }
        }

        if (is.null(fill_clr)){
          fill_clr <<- fill
        }else{
          fill_clr <<- matchClr(fill, fill_clr)
        }

        if (missing(txt) &&
              .self$noCols() == 2){
          if (length(.self$getDim()) == 3){
            txt <- c("#000000", "#ffffff")
          }else{
            txt <- c("#ffffff")
          }
        }

        if (is.null(txt_clr)){
          txt_clr <<- txt
        }else{
          txt_clr <<- matchClr(txt, txt_clr)
        }
      },
      getDim = function(){
        "Gets the current dimensions of the transitions"
        return(dim(transitions)[-length(dim(transitions))])
      },
      noRows = function(){
        "Gets the number of boxes in each row"
        return(.self$getDim()[1])
      },
      noCols = function(){
        "Gets the number of columns"
        return(tail(dim(transitions), 1) + 1)
      },
      boxSizes = function(col){
        "Gets the size of the boxes. The \\code{col} argumente shoud
        is either an integer or 'last'"
        if (is.character(col)){
          if(col == "last"){
            col <- .self$noCols()
          }
        }else if(is.numeric(col)){
          if (!col %in% 1:.self$noCols())
            stop("The column must be within the available columns 1 to ", .self$noCols(),
                 " while you have requested '", col, "'")
        }

        if (col == .self$noCols()){
          # Get last transition matrix and extract the column sums from that one
          mtrx <- asub(transitions, tail(dim(transitions), 1), dims = length(dim(transitions)))
          if (length(.self$getDim()) == 3){
            raw_sizes <- apply(mtrx, 3, colSums)
            sizes <- rowSums(raw_sizes)
            attr(sizes, "prop") <-
              raw_sizes[,1]/sizes
            return(sizes)
          }else if(length(.self$getDim()) == 2){
            return(colSums(mtrx))
          }else{
            stop("Invalid dimensionality of transition matrix: '", paste(.self$getDim(), collapse="', '"), "'")
          }
        }else{
          mtrx <- asub(transitions, col, dims = length(dim(transitions)))
          if (length(.self$getDim()) == 3){
            raw_sizes <- apply(mtrx, 3, rowSums)
            sizes <- rowSums(raw_sizes)
            attr(sizes, "prop") <-
              raw_sizes[,1]/sizes
            return(sizes)
          }else if(length(.self$getDim()) == 2){
            return(rowSums(mtrx))
          }else{
            stop("Invalid dimensionality of transition matrix: '", paste(.self$getDim(), collapse="', '"), "'")
          }
        }
      },
      getYProps = function (col) {
        "Gets the proportions after removing the \\code{vertical_space}
         between the boxes"
        vertical_sizes <- .self$boxSizes(col)
        (1 - convertY(vertical_space, 
                      unitTo = "npc", 
                      valueOnly = TRUE))*
          vertical_sizes/sum(vertical_sizes)
      },
      render = function(new_page = TRUE){
        "Call this to render the full graph. The \\code{new_page}} argument
        is for creating a new plot, set this to \\code{FALSE}
        if you want to combine this plot with another or if you have
        additional viewports that you intend to use."
        if (new_page)
          grid.newpage()

        prPushMarginViewport(bottom = mar[1],
                             left = mar[2],
                             top = mar[3],
                             right = mar[4],
                             "main_margins")
        on.exit(upViewport(2))


        if (!is.null(title)){
          prGridPlotTitle(title, title_cex, cex_mult = 1)
          on.exit(upViewport(2))
        }


        raw_width <- convertWidth(box_width, unitTo = "npc", valueOnly = TRUE)
        space_between <- (1- raw_width * .self$noCols())/(.self$noCols() - 1)

        if (!is.null(box_label)){
          raw_height <- convertHeight(grobHeight(textGrob("Aj", gp=gpar(cex=box_label_cex))),
                                      unitTo = "npc", valueOnly = TRUE)
          widths <- c()
          for (i in 1:.self$noCols()){
            widths %<>% c(raw_width)
            if (i != .self$noCols())
              widths %<>% c(space_between)
          }

          # Add margins
          pushViewport(viewport(layout = grid.layout(nrow = 2, ncol = length(widths),
                                                     heights = unit(c(raw_height * 2, 1-raw_height * 2), "npc"),
                                                     widths = unit(widths, "npc"))))
          for (i in 1:.self$noCols()){
            labelGrob <- textGrob(box_label[i], gp = gpar(cex = box_label_cex))
            pushViewport(viewport(layout.pos.row = 1, layout.pos.col = i + (i-1)))
            grid.draw(labelGrob)
            upViewport()
          }
          pushViewport(viewport(layout.pos.row = 2, layout.pos.col = 1:length(widths)))
          on.exit(upViewport(2))
        }

        shift <- unit(raw_width*.02, "snpc")
        pushViewport(viewport(x = unit(0.5, "npc")+shift,
                              y = unit(0.5, "npc")-shift,
                              height= unit(1, "npc")-shift-shift,
                              width= unit(1, "npc")-shift-shift, name="shadows"))
        upViewport()
        pushViewport(viewport(x = unit(0.5, "npc")-shift,
                              y = unit(0.5, "npc")+shift,
                              height= unit(1, "npc")-shift-shift,
                              width= unit(1, "npc")-shift-shift,
                              name="regular"))
        upViewport()

        for (col in 1:.self$noCols()){
          proportions <- getYProps(col)

          txt <- box_txt[,col]
          x_offset <- (raw_width + space_between) * (col - 1)

          box_args <- list(x_offset = x_offset,
                           width = box_width,
                           proportions = as.vector(proportions),
                           fill = rep(grey(level = .3), times = .self$noRows()),
                           txt = rep("", times = .self$noRows()),
                           txt_clr = rep(grey(level = .3), times = .self$noRows()),
                           cex = box_cex)
          seekViewport("shadows")
          fastDoCall(prTcPlotBoxColumn, box_args)
          upViewport()

          
          seekViewport("regular")
          box_args[["proportions"]] <- proportions
          box_args[["fill"]] <- asub(fill_clr, idx = col, dims = 2)
          box_args[["txt"]] <- box_txt[,col]
          box_args[["txt_clr"]] <- asub(txt_clr, idx = col, dims = 2)
          fastDoCall(prTcPlotBoxColumn, box_args)
          upViewport()
        }
      }
    )
  )