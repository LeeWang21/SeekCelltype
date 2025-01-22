#' Cell type annotation with Deepseek models
#'
#' @title Cell type annotation with Deepseek models
#'
#' @description Annotate cell types by OpenAI GPT models in a Seurat pipeline or with a custom gene list. If used in a Seurat pipeline, Seurat FindAllMarkers() function needs to be run first and the differential gene table generated by Seurat will serve as the input. If the input is a custom list of genes, one cell type is identified for each element in the list.  Note: system environment should have variable DEEPSEEK_API_KEY = 'your_api_key' or ''. If '', then output the prompt itself. If an actual key is provided, then the output will be the celltype annotations from the Deepseek model specified by the user. 
#' 
#' @param input Either the differential gene table returned by Seurat FindAllMarkers() function, or a list of genes.
#' @param tissuename Optional input of tissue name.
#' @param base_url The url for Deepseek model. Default is 'https://api.deepseek.com'.
#' @param model The Deepseek model. Default is 'deepseek-chat'. The optional models include 'deepseek-chat', 'deepseek-reasoner'
#' @param tissuename Optional input of tissue name.
#' @param DEEPSEEK_API_KEY The Deepseek key. The default is NULL, which will resulting outputing the prompt itself. If an actual key is provided, then the output will be the celltype annotations from the GPT model specified by the user. 
#' @param system_prompt Optional A system prompt to set the behavior of the assistant. Default is 'You are an expert bioinformatician in single-cell RNA data analysis'
#' @param seed Optional integer seed that Deepseek uses to try and make output more reproducible.
#' @param topgenenumber Number of top differential genes to be used if input is Seurat differential genes. Default is 20.
#' @param ... Optional The parameters used in ellmer::chat_openai().

#' @import ellmer 
#' @import dplyr
#' @export
#' @return A vector of cell types when the user provide Deepseek_key or the prompt itself when DEEPSEEK_API_KEY = NULL (default)
#' @author Wang Li <liwang@nibs.ac.cn>
#' @references Hou, W. and Ji, Z., 2023. Reference-free and cost-effective automated cell type annotation with GPT-4 in single-cell RNA-seq analysis. Nature Methods, 2024 March 25.

seekcelltype <- function(input, tissuename=NULL, base_url='https://api.deepseek.com', model='deepseek-chat', DEEPSEEK_API_KEY=NULL, system_prompt='You are an expert bioinformatician in single-cell RNA data analysis', seed=24, topgenenumber = 20, ...) {

  #DEEPSEEK_API_KEY <- Sys.getenv("DEEPSEEK_API_KEY")
  if (DEEPSEEK_API_KEY == "") {
    cat("Note: DEEPSEEK API key not found: returning the prompt itself.\n")
    API.flag <- 0
  } else {
    API.flag <- 1
  }
  
  if (class(input)=='list') {
    input <- sapply(input,paste,collapse=',')
  } else {
    input <- input %>% filter(p_val_adj <= 0.05) %>% group_by(cluster) %>% arrange(desc(avg_log2FC), .by_group = TRUE) %>% ungroup()
    input <- input[input$avg_log2FC > 0,,drop=FALSE]
    input <- tapply(input$gene,list(input$cluster),function(i) paste0(i[1:topgenenumber],collapse=','))
  }
  
  if (!API.flag){
   message = paste0('Identify cell types of ',tissuename,' cells using the following markers separately for each row. Only provide the cell type name. Do not show numbers before the name.\n Some can be a mixture of multiple cell types. ',  "\n", paste0(names(input), ':',unlist(input),collapse = "\n"))
    
    return(message)
    
  } else {
    cat("Note: DEEPSEEK API key found: returning the cell type annotations.\n")
    cutnum <- ceiling(length(input)/30)
    if (cutnum > 1) {
      cid <- as.numeric(cut(1:length(input),cutnum))	
    } else {
      cid <- rep(1,length(input))
    }
    
    allres <- sapply(1:cutnum,function(i) {
      id <- which(cid==i)
      flag <- 0
      while (flag == 0) {
        k <- ellmer::chat_openai(
            seed = seed,
            api_key = DEEPSEEK_API_KEY,
            base_url = base_url,
            system_prompt = system_prompt, 
            model = model,
            echo = 'none', ...
        )
        
        message = paste0('Identify cell types of ',tissuename,' cells using the following markers separately for each row. Only provide the cell type name. Do not show numbers before the name.\n Some can be a mixture of multiple cell types.\n',paste(input[id],collapse = '\n'))
        #print(message)
        res <- k$chat(message)
        res <- strsplit(res,'\n')[[1]]
        res <- gsub("^\\d+\\.\\s*", "", res)
        res <- trimws(res)
          
        if (length(res)==length(id))
          flag <- 1
      }
      names(res) <- names(input)[id]
      res
    },simplify = F) 
    cat('Note: It is always recommended to check the results returned by LLM in case of AI hallucination, before going to down-stream analysis.')
    return(gsub(',$','',unlist(allres)))
  }
  
}
