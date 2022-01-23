namespace MergePDF
{
    internal class QueueItem
    {
        public string SiteUrl { get; set; }
        public string FolderPath { get; set; }
        public string FileName { get; set; }
        public string[] FilesPathArray { get; set; }
    }
}
